#!/bin/bash
#
# DISCLAIMER: This code is provided as a sample for educational and testing purposes only.
# Users must perform their own security review and due diligence before deploying any code
# to production environments. The code provided represents a baseline implementation and
# may not address all security considerations for your specific environment.
#
set -e

# Default values
PRI_DOMAIN=""
DR_DOMAIN=""
PRI_REGION=""
DR_REGION=""
OWNER_ID=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --pri-domain)
      PRI_DOMAIN="$2"
      shift
      shift
      ;;
    --dr-domain)
      DR_DOMAIN="$2"
      shift
      shift
      ;;
    --pri-region)
      PRI_REGION="$2"
      shift
      shift
      ;;
    --dr-region)
      DR_REGION="$2"
      shift
      shift
      ;;
    --owner-id)
      OWNER_ID="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if required parameters are provided
if [ -z "${PRI_DOMAIN}" ] || [ -z "${DR_DOMAIN}" ] || [ -z "${PRI_REGION}" ] || [ -z "${DR_REGION}" ] || [ -z "${OWNER_ID}" ]; then
  echo "Error: Required parameters missing."
  echo "Usage: $0 --pri-domain <primary-domain> --dr-domain <dr-domain> --pri-region <primary-region> --dr-region <dr-region> --owner-id <aws-account-id>"
  exit 1
fi

# Function for retrying commands
retry() {
    local attempts=3
    local wait=10
    local cmd="$@"
    
    for ((i=1; i<=attempts; i++)); do
        echo "Attempt $i: Running command..."
        if eval "$cmd"; then
            return 0
        fi
        echo "Command failed. Waiting $wait seconds before retry..."
        sleep $wait
    done
    echo "Error: Command failed after $attempts attempts"
    return 1
}

echo "Setting up cross-region replication between ${PRI_DOMAIN} and ${DR_DOMAIN}"
echo "Primary region: ${PRI_REGION}"
echo "DR region: ${DR_REGION}"
echo "AWS Account ID: ${OWNER_ID}"

# Create outbound connection
echo "Creating outbound connection..."
CONN_ID=$(aws opensearch create-outbound-connection \
    --local-domain-info "{\"AWSDomainInformation\": {\"OwnerId\": \"${OWNER_ID}\", \"DomainName\": \"${DR_DOMAIN}\", \"Region\": \"${DR_REGION}\"}}" \
    --remote-domain-info "{\"AWSDomainInformation\": {\"OwnerId\": \"${OWNER_ID}\", \"DomainName\": \"${PRI_DOMAIN}\", \"Region\": \"${PRI_REGION}\"}}" \
    --connection-alias "dr_connection" \
    --connection-mode "DIRECT" \
    --query 'ConnectionId' \
    --output text)

echo "Connection ID: ${CONN_ID}"

# Wait for connection creation
echo "Waiting for connection creation (30 seconds)..."
sleep 30

# Accept inbound connection
echo "Accepting inbound connection..."
aws opensearch accept-inbound-connection --connection-id "${CONN_ID}" --region "${PRI_REGION}"

# Wait for connection establishment
echo "Waiting for connection establishment (30 seconds)..."
sleep 30

# Get DR domain endpoint
DR_ENDPOINT=$(aws opensearch describe-domain \
    --domain-name "${DR_DOMAIN}" \
    --region "${DR_REGION}" \
    --query 'DomainStatus.Endpoints.vpc' \
    --output text)

if [ -z "${DR_ENDPOINT}" ]; then
    echo "Failed to get DR domain endpoint. Trying alternative method..."
    DR_ENDPOINT=$(aws opensearch describe-domain \
        --domain-name "${DR_DOMAIN}" \
        --region "${DR_REGION}" \
        --query 'DomainStatus.Endpoint' \
        --output text)
fi

if [ -z "${DR_ENDPOINT}" ]; then
    echo "Error: Could not retrieve DR domain endpoint"
    exit 1
fi

echo "DR domain endpoint: ${DR_ENDPOINT}"

# Start autofollow rule
echo "Setting up autofollow rule..."
curl -XPOST "https://${DR_ENDPOINT}/_plugins/_replication/_autofollow" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{
        "leader_alias": "dr_connection",
        "name": "dr-replication",
        "pattern": "*",
        "use_roles": {
            "leader_cluster_role": "all_access",
            "follower_cluster_role": "all_access"
        }
    }'

echo ""
echo "Cross-region replication setup completed successfully"
