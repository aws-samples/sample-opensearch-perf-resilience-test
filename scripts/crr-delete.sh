#!/bin/bash
set -e

# Default values
PRI_DOMAIN=""
DR_DOMAIN=""
PRI_REGION=""
DR_REGION=""
OWNER_ID=""
PRI_ENDPOINT=""
DR_ENDPOINT=""

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
    --pri-endpoint)
      PRI_ENDPOINT="$2"
      shift
      shift
      ;;
    --dr-endpoint)
      DR_ENDPOINT="$2"
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
if [ -z "${PRI_DOMAIN}" ] || [ -z "${DR_DOMAIN}" ] || [ -z "${PRI_REGION}" ] || [ -z "${DR_REGION}" ] || [ -z "${PRI_ENDPOINT}" ] || [ -z "${DR_ENDPOINT}" ]; then
  echo "Error: Required parameters missing."
  echo "Usage: $0 --pri-domain <primary-domain> --dr-domain <dr-domain> --pri-region <primary-region> --dr-region <dr-region> --pri-endpoint <primary-endpoint> --dr-endpoint <dr-endpoint> [--owner-id <aws-account-id>]"
  exit 1
fi

echo "Starting cross-region replication cleanup..."
echo "Primary domain: ${PRI_DOMAIN} (${PRI_ENDPOINT})"
echo "DR domain: ${DR_DOMAIN} (${DR_ENDPOINT})"

# Get all follower indices and store them in a variable
echo "Retrieving follower indices..."
follower_indices=$(curl -s -X GET "${DR_ENDPOINT}/_plugins/_replication/follower_stats" \
  -u "admin:Admin123!" \
  -H "Content-Type: application/json" \
  | jq -r '.index_stats | keys[]')

if [ -z "${follower_indices}" ]; then
  echo "No follower indices found."
else
  echo "Found follower indices: ${follower_indices}"
  
  # Loop through each follower index
  for index in ${follower_indices}; do
      echo "Processing index: ${index}"
      
      # Stop replication
      echo "Stopping replication for ${index}..."
      curl -X POST "${DR_ENDPOINT}/_plugins/_replication/${index}/_stop" \
          -H "Content-Type: application/json" \
          -u "admin:Admin123!" \
          -d '{}'
      
      # Remove follower index
      echo "Removing follower index ${index} from DR domain..."
      curl -X DELETE "${DR_ENDPOINT}/${index}" -u "admin:Admin123!"
      
      echo "Removing index ${index} from primary domain..."
      curl -X DELETE "${PRI_ENDPOINT}/${index}" -u "admin:Admin123!"
  done
fi

echo "All replication stopped and indices removed."

# Get connection ID
echo "Retrieving connection ID..."
CONN_ID=$(aws opensearch describe-outbound-connections \
  --region "${DR_REGION}" \
  --query 'Connections[?ConnectionAlias==`dr_connection`].ConnectionId' \
  --output text)

if [ -z "${CONN_ID}" ]; then
  echo "No connection ID found with alias 'dr_connection'."
else
  echo "Found connection ID: ${CONN_ID}"
  
  # Delete connection ID
  echo "Deleting outbound connection..."
  aws opensearch delete-outbound-connection --connection-id "${CONN_ID}" --region "${DR_REGION}"
  echo "Outbound connection deleted."
fi

echo "Cross-region replication cleanup completed successfully."
