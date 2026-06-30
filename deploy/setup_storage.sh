#!/bin/bash
# Set up Google Cloud Storage bucket for storing model weights
# Usage: ./setup_storage.sh

set -e

# Load environment configuration
source "$(dirname "$0")/set_env.sh"

echo "Configuring Cloud Storage..."

# 1. Create the bucket if it doesn't exist
if gcloud storage buckets describe "gs://${BUCKET_NAME}" >/dev/null 2>&1; then
    echo "Bucket gs://${BUCKET_NAME} already exists."
else
    echo "Creating Cloud Storage bucket gs://${BUCKET_NAME} in location ${REGION}..."
    gcloud storage buckets create "gs://${BUCKET_NAME}" \
        --location="${REGION}" \
        --uniform-bucket-level-access
fi

# 2. Grant the runtime service account object viewer permissions
echo "Granting storage object viewer permissions to service account ${SERVICE_ACCOUNT_EMAIL}..."
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/storage.objectViewer"

echo "Storage configuration completed successfully."
