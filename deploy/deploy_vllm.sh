#!/bin/bash
# Trigger the Cloud Build pipeline to build and deploy the vLLM service
# Usage: ./deploy_vllm.sh

set -e

# Load environment configuration
source "$(dirname "$0")/set_env.sh"

echo "Submitting Cloud Build job to build and deploy the vLLM container..."

gcloud builds submit \
  --config="$(dirname "$0")/cloudbuild-deploy.yaml" \
  --substitutions="_REGION=${REGION},_REPO_NAME=${REPO_NAME},_SERVICE_ACCOUNT_EMAIL=${SERVICE_ACCOUNT_EMAIL},_VPC_NETWORK=${VPC_NETWORK},_VPC_SUBNET=${VPC_SUBNET},_MODELS_BUCKET=${BUCKET_NAME},_MODEL_PATH=${MODEL_PATH}" \
  "$(dirname "$0")"

echo "vLLM service deployment build submitted. Check the Google Cloud Console to monitor progress."
