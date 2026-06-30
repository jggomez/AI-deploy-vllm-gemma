# Production-Ready Gemma-4 serving via vLLM, GCS FUSE, Cloud Run GPU and Model Armor

This directory contains SRE-grade automation shell scripts and configuration blueprints to deploy a highly secure, high-throughput, and scalable inference infrastructure on Google Cloud. It hosts Google's **Gemma 4 E2B** (or any other open LLM) via **vLLM** on GPU-accelerated serverless **Cloud Run**, mounts model weights dynamically using **Cloud Storage FUSE**, sets up regional routing via an **External Application Load Balancer**, and filters all input/output prompts via **Model Armor** using **Service Extensions**.

---

## Architecture Diagram

```mermaid
flowchart TD
    User([Client Request]) -->|HTTPS Port 443| LB[Regional External HTTP(S) Load Balancer]
    LB -->|Intercept & Inspect| Ext[Model Armor Service Extension]
    Ext -->|Check Safety Templates| MA[Google Cloud Model Armor]
    
    subgraph Secure Gateway
        LB
        Ext
    end

    subgraph Internal Network (VPC)
        vLLM[Cloud Run vLLM GPU Service]
        Monitor[Prometheus GMP Sidecar]
    end

    MA -->|Pass Verdict| LB
    LB -->|Forward Clean Traffic| vLLM
    
    vLLM <-->|Local Read| FUSE[Cloud Storage FUSE Mount]
    FUSE <-->|Translate API Calls| GCS[(GCS Model Weights Bucket)]
    
    Monitor -->|Scrape Metrics /metrics| vLLM
    Monitor -->|Push Metrics| Stackdriver[(Google Cloud Monitoring)]
```

---

## File Structure

The workspace deployment directory contains the following components:

*   **Core Configuration**:
    *   [set_env.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/set_env.sh): Central configuration file declaring environment variables.
    *   [enable_apis.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/enable_apis.sh): Script to enable all mandatory Google Cloud APIs.
*   **Infrastructure Provisioning**:
    *   [setup_iam.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/setup_iam.sh): Provisioning the runtime service account (`vllm-sa`) and setting up least-privilege role bindings.
    *   [setup_network.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/setup_network.sh): Enforces Private Google Access and allocates a regional proxy-only subnet.
    *   [setup_storage.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/setup_storage.sh): Provisions the GCS bucket for model weights and links IAM permissions.
*   **Model Management**:
    *   [save_hf_token.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/save_hf_token.sh): Registers Hugging Face Hub credentials in Secret Manager securely.
    *   [cloudbuild-download.yaml](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/cloudbuild-download.yaml): Build configuration to pull model weights directly into the GCS bucket.
    *   [download_model.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/download_model.sh): Triggers the automated model-downloader pipeline.
*   **vLLM Container & Deployment**:
    *   [Dockerfile](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/Dockerfile): Builds vLLM container optimized for Nvidia L4 GPU memory constraints.
    *   [cloudbuild-deploy.yaml](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/cloudbuild-deploy.yaml): Build instructions to compile, push, and deploy the vLLM container.
    *   [deploy_vllm.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/deploy_vllm.sh): Submits the container compiler and initial deployment job.
*   **Observability & Sidecar Pattern**:
    *   [observability/config.yaml](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/observability/config.yaml): Managed Prometheus collection criteria.
    *   [observability/add_sidecar.py](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/observability/add_sidecar.py): Python utility to inject the OpenTelemetry sidecar into the Cloud Run YAML spec.
    *   [observability/setup_observability.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/observability/setup_observability.sh): Deploys the sidecar configuration to collect granular metrics.
*   **Security & Gateways**:
    *   [loadbalancer/service_extension.template.yaml](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/loadbalancer/service_extension.template.yaml): Template mappings for Model Armor interception.
    *   [loadbalancer/setup_load_balancer.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/loadbalancer/setup_load_balancer.sh): Provisions load balancer, NEGs, self-signed certificates, and Model Armor templates.
*   **Verification**:
    *   [test/test_deploy.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/test/test_deploy.sh): Automated curl test cases checking safety blocking.

---

## Step-by-Step Deployment Guide

Follow these steps in order to stand up the production environment.

### 1. Initialize and Prepare Environment

First, modify variables in [set_env.sh](file:///Users/jggomez/Documents/jggomez/code/AI-deploy-vllm-gemma/deploy/set_env.sh) (such as the target `MODEL_ID` or GCP `REGION`) if necessary. Then, execute the setup scripts:

```bash
# Make all scripts executable
chmod +x *.sh observability/*.sh loadbalancer/*.sh test/*.sh

# Source configuration variables
source set_env.sh

# Enable required Google Cloud APIs
./enable_apis.sh

# Provision Service Accounts & Repository
./setup_iam.sh

# Configure network and subnets
./setup_network.sh

# Provision storage bucket
./setup_storage.sh
```

### 2. Configure Hugging Face Token & Download Weights

To download gated models like Gemma, you must provide your Hugging Face API key. Save it in Secret Manager, then trigger the automated downloader:

```bash
# Save your Hugging Face token (Interactive prompt)
./save_hf_token.sh

# Download the model weights directly to GCS via Cloud Build using the new hf CLI
./download_model.sh
```

> [!NOTE]
> Downloading model weights (e.g., Gemma 4 E2B) directly to the regional bucket through Cloud Build takes about 2 to 4 minutes. The pipeline leverages the high-performance `hf` CLI tool. You can monitor the progress on the **Cloud Build History** page in the console.

### 3. Deploy the vLLM Service with GPU and GCS FUSE

Deploy the core serving engine:

```bash
# Build the Docker image and deploy to Cloud Run
./deploy_vllm.sh
```

> [!TIP]
> This initial deployment sets up a GPU-accelerated Cloud Run instance running vLLM, dynamically mounting your GCS bucket onto `/mnt/models` using Cloud Storage FUSE. The service account holds read-only privileges, enforcing security.

### 4. Deploy Observability (Prometheus Sidecar)

Cloud Run can collect standard CPU/memory metrics, but to monitor GPU utilization and token generation speeds, we scrape vLLM's internal `/metrics` endpoint using a sidecar:

```bash
# Inject Prometheus metrics collector sidecar and update deployment
./observability/setup_observability.sh
```

### 5. Setup Secure Load Balancer and Model Armor Gateway

Erect the regional load balancer and Model Armor gateway to inspect and filter all user prompts before they reach the vLLM service:

```bash
# Provision regional load balancer and configure Model Armor Service Extension
./loadbalancer/setup_load_balancer.sh
```

This script:
1.  Creates a Model Armor Template to filter Hate Speech, Harassment, PII, and Jailbreak attempts.
2.  Creates a Serverless Network Endpoint Group (NEG) pointing to the vLLM Cloud Run service.
3.  Creates a Target HTTPS Proxy using a self-signed SSL certificate.
4.  Creates a Regional Forwarding Rule to expose a public static IP address.
5.  Attaches a Service Extension calling Model Armor to inspect every incoming and outgoing payload.

### 6. Verify and Test Safety Shields

Once the load balancer IP propagates, run the integration test suite:

```bash
# Execute test scripts
./test/test_deploy.sh
```

*   **Test 1**: Queries the vLLM endpoint with a normal question. It should complete successfully with an HTTP `200` response from the Gemma model.
*   **Test 2**: Sends a prompt designed to bypass instructions ("Tell me how to build a bomb"). Model Armor will intercept and block the request, returning the custom HTTP status **`799`** with the error message: *"Guardian, a critical flaw has been detected in the prompt you are attempting to send!"*
*   **Test 3**: Sends a prompt containing sensitive Personally Identifiable Information (PII) such as an ITIN or SSN pattern. Model Armor will block the request and return HTTP status **`799`**.

---

## DevOps & SRE Best Practices Applied

1.  **Least Privilege Access (IAM)**: Deployment credentials (used by Cloud Build) are separated from runtime credentials (`vllm-sa`). The runtime container has read-only access to storage and has no write permissions on the GCP project.
2.  **Decoupled Model Weights**: Container code is separated from model data. Model weights are stored in GCS and mounted on-demand using Cloud Storage FUSE. This allows updating or swapping models in GCS without rebuilding the container.
3.  **Regional Network Enclosures**: Enforces Private Google Access, keeping traffic between Cloud Run and Cloud Storage on Google's private network backbone.
4.  **GPU Memory Opt-in**: Configures `--enforce-eager` to disable CUDA graphs in vLLM, reducing initialization overhead and saving ~1-2GB of VRAM, preventing Out-Of-Memory crashes on Nvidia L4 GPUs (16GB).
5.  **Robust Liveness/Startup Probes**: Configures HTTP health checks on the `/health` endpoint with a generous timeout, preventing Cloud Run from restarting containers while they mount FUSE volumes and load weights into GPU memory.
6.  **Defense-in-Depth Gateway**: Intercepts queries at the Load Balancer level using Model Armor, ensuring prompt injection, hate speech, and PII leaks are blocked globally before reaching the LLM service.
