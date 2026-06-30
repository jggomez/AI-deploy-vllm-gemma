#!/usr/bin/env python3
import yaml
import sys
import os

# --- Configuration ---
INPUT_FILE = 'vllm-cloudrun.yaml'
OUTPUT_FILE = 'service.yaml'
MAIN_APP_NAME = 'app' # The required name for the main application container when using sidecars
GMP_SIDECAR_NAME = 'collector'
GMP_SECRET_NAME = 'vllm-monitor-config' # The secret that holds the GMP config.yaml

def main():
    """
    Reads a Cloud Run service YAML, modifies it to add the Google Managed Prometheus sidecar,
    configures container dependencies, and writes the new configuration to service.yaml.
    """
    # 1. Get environment variables
    project_id = os.environ.get('PROJECT_ID')
    if not project_id:
        print("ERROR: Environment variable PROJECT_ID is not set.", file=sys.stderr)
        sys.exit(1)

    # 2. Define the sidecar container definition
    gmp_sidecar_container = {
        'name': GMP_SIDECAR_NAME,
        'image': 'us-docker.pkg.dev/cloud-ops-agents-artifacts/cloud-run-gmp-sidecar/cloud-run-gmp-sidecar:1.2.0',
        'volumeMounts': [{'name': 'config', 'mountPath': '/etc/rungmp/'}]
    }

    # 3. Define the secret volume configuration
    gmp_volume = {
        'name': 'config',
        'secret': {
            'secretName': GMP_SECRET_NAME,
            'items': [{'key': 'latest', 'path': 'config.yaml'}]
        }
    }

    # 4. Read the source YAML file
    try:
        with open(INPUT_FILE, 'r') as f:
            service_data = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"ERROR: Input file '{INPUT_FILE}' not found.", file=sys.stderr)
        print("Please ensure you run: gcloud run services describe gemma-vllm-fuse-service --format=yaml > vllm-cloudrun.yaml", file=sys.stderr)
        sys.exit(1)

    # 5. Extract service container details
    # We must rename the primary vLLM container to 'app' to define dependency rules
    containers = service_data['spec']['template']['spec']['containers']
    
    # Locate the main container (either named 'gemma-vllm-fuse-service', having no name, or the first container)
    main_container_updated = False
    for container in containers:
        name = container.get('name')
        if name == 'gemma-vllm-fuse-service' or name is None:
            container['name'] = MAIN_APP_NAME
            main_container_updated = True
            break
            
    if not main_container_updated:
        # Fallback to the first container
        print(f"Renaming first container to '{MAIN_APP_NAME}'...")
        containers[0]['name'] = MAIN_APP_NAME

    # Add sidecar if it doesn't exist
    if not any(c['name'] == GMP_SIDECAR_NAME for c in containers):
        containers.append(gmp_sidecar_container)
        print("Injected Prometheus sidecar container definition.")

    # 6. Add volumes if they don't exist
    volumes = service_data['spec']['template']['spec'].get('volumes', [])
    if not any(v['name'] == 'config' for v in volumes):
        volumes.append(gmp_volume)
        service_data['spec']['template']['spec']['volumes'] = volumes
        print("Injected config volume definition.")

    # 7. Add required annotations for dependencies and secrets
    annotations = service_data['spec']['template']['metadata'].get('annotations', {})
    
    # Set startup dependency: 'collector' starts after 'app' (main vLLM app)
    annotations['run.googleapis.com/container-dependencies'] = f'{{"{GMP_SIDECAR_NAME}":["{MAIN_APP_NAME}"]}}'
    
    # Map the secret mount
    secret_path = f'{GMP_SECRET_NAME}:projects/{project_id}/secrets/{GMP_SECRET_NAME}'
    existing_secrets = annotations.get('run.googleapis.com/secrets')
    if existing_secrets:
        if GMP_SECRET_NAME not in existing_secrets:
            annotations['run.googleapis.com/secrets'] = f"{existing_secrets},{secret_path}"
    else:
        annotations['run.googleapis.com/secrets'] = secret_path

    service_data['spec']['template']['metadata']['annotations'] = annotations
    print("Injected startup dependency and secret annotations.")

    # 8. Clean up read-only system metadata that would reject replacement API calls
    if 'metadata' in service_data:
        for field in ['uid', 'resourceVersion', 'generation', 'creationTimestamp', 'selfLink']:
            service_data['metadata'].pop(field, None)
    if 'status' in service_data:
        service_data.pop('status')

    # 9. Save output to service.yaml
    with open(OUTPUT_FILE, 'w') as f:
        yaml.dump(service_data, f, default_flow_style=False)
    
    print(f"Successfully generated custom spec '{OUTPUT_FILE}'. You can now deploy it.")

if __name__ == '__main__':
    main()
