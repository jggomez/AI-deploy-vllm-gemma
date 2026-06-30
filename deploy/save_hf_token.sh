#!/bin/bash
# Save Hugging Face Access Token to Secret Manager
# Usage: ./save_hf_token.sh <HF_TOKEN> (or interactive prompt)

set -e

# Load environment configuration
source "$(dirname "$0")/set_env.sh"

HF_TOKEN=$1

# Interactive prompt if token is not provided
if [ -z "${HF_TOKEN}" ]; then
    echo -n "Enter your Hugging Face Access Token (Read role is sufficient): "
    read -s HF_TOKEN
    echo ""
fi

if [ -z "${HF_TOKEN}" ]; then
    echo "ERROR: Hugging Face Token cannot be empty."
    exit 1
fi

SECRET_NAME="hf-secret"

# 1. Create the secret if it doesn't exist
if gcloud secrets describe "${SECRET_NAME}" >/dev/null 2>&1; then
    echo "Secret '${SECRET_NAME}' already exists."
else
    echo "Creating secret '${SECRET_NAME}' in Secret Manager..."
    gcloud secrets create "${SECRET_NAME}" \
        --replication-policy="automatic" \
        --project="${PROJECT_ID}"
fi

# 2. Add the token value as a secret version
echo "Adding new version to secret '${SECRET_NAME}'..."
echo -n "${HF_TOKEN}" | gcloud secrets versions add "${SECRET_NAME}" \
    --data-file=- \
    --project="${PROJECT_ID}"

# 3. Ensure Cloud Build service account can access this secret
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo "Granting Secret Accessor role to Cloud Build Service Account: ${BUILD_SA}"
gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="${PROJECT_ID}" \
    --quiet

echo "Hugging Face token successfully stored in Secret Manager."
