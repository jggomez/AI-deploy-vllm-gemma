#!/bin/bash
# Configure networking for Cloud Run GCS FUSE and Regional Load Balancer
# Usage: ./setup_network.sh

set -e

# Load environment configuration
source "$(dirname "$0")/set_env.sh"

echo "Configuring networking in region ${REGION}..."

# 1. Enable Private Google Access on the subnet (required for Cloud Storage FUSE)
echo "Enabling Private Google Access on subnet '${VPC_SUBNET}'..."
gcloud compute networks subnets update "${VPC_SUBNET}" \
    --region="${REGION}" \
    --enable-private-ip-google-access

# 2. Create proxy-only subnet for the Regional External Load Balancer
# Check if the proxy-only subnet already exists
if gcloud compute networks subnets describe "proxy-only-subnet" --region="${REGION}" >/dev/null 2>&1; then
    echo "Proxy-only subnet 'proxy-only-subnet' already exists in region ${REGION}."
else
    echo "Creating proxy-only subnet for regional load balancer..."
    gcloud compute networks subnets create "proxy-only-subnet" \
        --purpose="REGIONAL_MANAGED_PROXY" \
        --role="ACTIVE" \
        --region="${REGION}" \
        --network="${VPC_NETWORK}" \
        --range="192.168.10.0/26"
fi

echo "Networking configuration completed successfully."
