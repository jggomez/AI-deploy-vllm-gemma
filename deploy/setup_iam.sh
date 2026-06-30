#!/bin/bash
# Set up IAM Service Accounts and Permissions for vLLM deployment
# Usage: ./setup_iam.sh

set -e

# Load environment configuration
source "$(dirname "$0")/set_env.sh"

PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo "Project Number: ${PROJECT_NUMBER}"
echo "Build Service Account: ${BUILD_SA}"

# 1. Create the runtime service account if it doesn't exist
if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Creating runtime service account: ${SERVICE_ACCOUNT_NAME}..."
    gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
        --project="${PROJECT_ID}" \
        --description="Service account for running vLLM Gemma service" \
        --display-name="vLLM Runtime Service Account"
    echo "Sleeping for 10 seconds to allow IAM propagation..."
    sleep 10
else
    echo "Runtime service account ${SERVICE_ACCOUNT_NAME} already exists."
fi

# 2. Grant roles to the Runtime Service Account (Least Privilege)
echo "Granting roles to runtime service account: ${SERVICE_ACCOUNT_EMAIL}..."

# Read-only access to Storage (for GCS FUSE mount)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/storage.objectViewer" \
    --quiet

# Logging writer
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/logging.logWriter" \
    --quiet

# Monitoring metric writer
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/monitoring.metricWriter" \
    --quiet

# aiplatform.user (needed if integrating with Vertex AI services/Model Armor)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/aiplatform.user" \
    --quiet

# 3. Grant roles to the Cloud Build Service Account (to allow deployment)
echo "Granting roles to builder service account: ${BUILD_SA}..."

# Allow Cloud Build to deploy Cloud Run services
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/run.admin" \
    --quiet

# Allow Cloud Build to act as the runtime service account (Service Account User)
gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT_EMAIL}" \
    --project="${PROJECT_ID}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/iam.serviceAccountUser" \
    --quiet

# Allow Cloud Build to write to Artifact Registry
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/artifactregistry.admin" \
    --quiet

# Allow Cloud Build to access secrets (for Hugging Face token download)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet

# Allow Cloud Build to write logs
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/logging.logWriter" \
    --quiet

# Create the Artifact Registry repository if it doesn't exist
if ! gcloud artifacts repositories describe "${REPO_NAME}" --location="${REGION}" >/dev/null 2>&1; then
    echo "Creating Artifact Registry repository: ${REPO_NAME} in ${REGION}..."
    gcloud artifacts repositories create "${REPO_NAME}" \
        --repository-format=docker \
        --location="${REGION}" \
        --description="Docker repository for vLLM images"
else
    echo "Artifact Registry repository ${REPO_NAME} already exists."
fi

echo "IAM configuration completed successfully."
