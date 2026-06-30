#!/bin/bash
# Configure Prometheus metrics sidecar and apply it to the vLLM service
# Usage: ./setup_observability.sh

set -e

# Load environment configuration
source "$(dirname "$0")/../set_env.sh"

echo "Setting up observability for the vLLM service..."

# Ensure we are in the observability directory
cd "$(dirname "$0")"

SECRET_NAME="vllm-monitor-config"

# 1. Store the config.yaml inside Secret Manager
if gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Secret '${SECRET_NAME}' already exists. Creating a new version..."
else
    echo "Creating secret '${SECRET_NAME}' in Secret Manager..."
    gcloud secrets create "${SECRET_NAME}" \
        --replication-policy="automatic" \
        --project="${PROJECT_ID}"
fi

gcloud secrets versions add "${SECRET_NAME}" \
    --data-file="config.yaml" \
    --project="${PROJECT_ID}"

# 2. Grant the runtime service account access to the monitor secret
echo "Granting secret accessor permissions to service account ${SERVICE_ACCOUNT_EMAIL}..."
gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="${PROJECT_ID}" \
    --quiet

# 3. Export the current live service configuration to a temporary YAML
echo "Exporting current vLLM service configuration..."
gcloud run services describe gemma-vllm-fuse-service \
    --region="${REGION}" \
    --format=yaml > vllm-cloudrun.yaml

# 4. Run python injector script
echo "Running injector script to add sidecar..."
python3 add_sidecar.py

# 5. Apply the new config back to Cloud Run
echo "Deploying sidecar-enabled service specification to Cloud Run..."
gcloud run services replace service.yaml \
    --region="${REGION}"

echo "Observability sidecar successfully deployed."
echo "Your vLLM service is now emitting Prometheus metrics on port 8000."
