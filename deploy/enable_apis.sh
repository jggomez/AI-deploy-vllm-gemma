#!/bin/bash
# Enable required Google Cloud APIs for Gemma vLLM deployment
# Usage: ./enable_apis.sh

set -e

# Load environment configuration
source "$(dirname "$0")/set_env.sh"

echo "Enabling necessary Google Cloud APIs..."

gcloud services enable \
    storage.googleapis.com \
    aiplatform.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com \
    compute.googleapis.com \
    cloudresourcemanager.googleapis.com \
    containeranalysis.googleapis.com \
    modelarmor.googleapis.com \
    networkservices.googleapis.com \
    secretmanager.googleapis.com

echo "All required APIs enabled successfully."
