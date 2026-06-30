#!/bin/bash
# Centralized configuration variables for Gemma vLLM deployment on Cloud Run
# Source this file before running any other scripts: source set_env.sh

# Google Cloud Configuration
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-west4" # Adjust to a region supporting L4 GPUs and Model Armor
export REPO_NAME="agentverse-repo"
export SERVICE_ACCOUNT_NAME="vllm-sa"
export SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Network Configuration
export VPC_NETWORK="default"
export VPC_SUBNET="default"

# Storage & Model Configuration
export BUCKET_NAME="${PROJECT_ID}-vllm-models-${REGION}"
export MODEL_ID="google/gemma-4-E2B-it" # Model name from Hugging Face
export MODEL_DIR_NAME="gemma-4-E2B-it"   # The directory name to store inside the bucket
export MODEL_PATH="/mnt/models/${MODEL_DIR_NAME}"

# Model Armor Security Configuration
export ARMOR_TEMPLATE_ID="vllm-gemma-armor-template"

# Print configuration summary
echo "========================================="
echo "Gemma vLLM Deployment Configuration:"
echo "========================================="
echo "Project ID:      ${PROJECT_ID}"
echo "Region:          ${REGION}"
echo "Registry Repo:   ${REPO_NAME}"
echo "Service Account: ${SERVICE_ACCOUNT_EMAIL}"
echo "VPC Network:     ${VPC_NETWORK}"
echo "VPC Subnet:      ${VPC_SUBNET}"
echo "Models Bucket:   gs://${BUCKET_NAME}"
echo "Model ID:        ${MODEL_ID}"
echo "Model Path:      ${MODEL_PATH}"
echo "Model Armor ID:  ${ARMOR_TEMPLATE_ID}"
echo "========================================="
