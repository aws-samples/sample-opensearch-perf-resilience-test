#!/bin/bash
set -e

# Default values
PRI_DOMAIN=""
DR_DOMAIN=""
PRI_REGION=""
DR_REGION=""
DOMAIN_ENDPOINT_DR=""
DOMAIN_ENDPOINT_PRI=""

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
    --dr-endpoint)
      DOMAIN_ENDPOINT_DR="$2"
      shift
      shift
      ;;
    --pri-endpoint)
      DOMAIN_ENDPOINT_PRI="$2"
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
if [ -z "$PRI_DOMAIN" ] || [ -z "$DR_DOMAIN" ] || [ -z "$PRI_REGION" ] || [ -z "$DR_REGION" ] || [ -z "$DOMAIN_ENDPOINT_DR" ] || [ -z "$DOMAIN_ENDPOINT_PRI" ]; then
  echo "Error: Required parameters missing."
  echo "Usage: $0 --pri-domain <primary-domain> --dr-domain <dr-domain> --pri-region <primary-region> --dr-region <dr-region> --dr-endpoint <dr-endpoint> --pri-endpoint <primary-endpoint>"
  exit 1
fi

echo "Starting cross-region replication cleanup..."
echo "Primary Domain: $PRI_DOMAIN"
echo "DR Domain: $DR_DOMAIN"
echo "Primary Region: $PRI_REGION"
echo "DR Region: $DR_REGION"
echo "Primary Endpoint: $DOMAIN_ENDPOINT_PRI"
echo "DR Endpoint: $DOMAIN_ENDPOINT_DR"

# Get all follower indices and store them in a variable
echo "Retrieving follower indices..."
follower_indices=$(curl -s -X GET "$DOMAIN_ENDPOINT_DR/_plugins/_replication/follower_stats" \
    -u "admin:Admin123!" \
    -k \
    -H "Content-Type: application/json" \
    | jq -r '.index_stats | keys[]')

if [ -z "$follower_indices" ]; then
    echo "No follower indices found."
else
    echo "Found follower indices: $follower_indices"
    
    # Loop through each follower index
    for index in $follower_indices; do
        echo "Stopping replication for index: $index"
        # Stop replication
        curl -X POST "$DOMAIN_ENDPOINT_DR/_plugins/_replication/$index/_stop" \
            -H "Content-Type: application/json" \
            -u "admin:Admin123!" \
            -k \
            -d '{}'
        
        echo "Removing follower index: $index"
        # Remove follower index
        curl -X DELETE "$DOMAIN_ENDPOINT_DR/$index" -u "admin:Admin123!" -k
        
        echo "Removing leader index: $index"
        # Remove leader index
        curl -X DELETE "$DOMAIN_ENDPOINT_PRI/$index" -u "admin:Admin123!" -k
    done
fi

echo "Stopped all replication"

# Get connection ID
echo "Retrieving connection ID..."
CONN_ID=$(aws opensearch describe-outbound-connections \
    --region $DR_REGION \
    --query 'Connections[?ConnectionAlias==`dr_connection`].ConnectionId' \
    --output text)

if [ -z "$CONN_ID" ]; then
    echo "No connection ID found with alias 'dr_connection'"
else
    echo "Found connection ID: $CONN_ID"
    
    # Delete connection ID
    echo "Deleting outbound connection..."
    aws opensearch delete-outbound-connection --connection-id $CONN_ID --region $DR_REGION
    
    echo "Connection deleted successfully"
fi

echo "Cross-region replication cleanup completed"
