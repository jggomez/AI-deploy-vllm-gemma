#!/bin/bash
# Trigger the Cloud Build pipeline to download the model weights to GCS
# Usage: ./download_model.sh

set -e

# Load environment configuration
source "$(dirname "$0")/set_env.sh"

echo "Submitting Cloud Build job to download ${MODEL_ID} to gs://${BUCKET_NAME}/${MODEL_DIR_NAME}..."

gcloud builds submit \
  --config="$(dirname "$0")/cloudbuild-download.yaml" \
  --substitutions="_MODEL_ID=${MODEL_ID},_MODELS_BUCKET=${BUCKET_NAME},_MODEL_DIR_NAME=${MODEL_DIR_NAME}" \
  "$(dirname "$0")"

echo "Model download build submitted. Check the Google Cloud Console to monitor progress."
