#!/bin/bash
#
# DISCLAIMER: This code is provided as a sample for educational and testing purposes only.
# Users must perform their own security review and due diligence before deploying any code
# to production environments. The code provided represents a baseline implementation and
# may not address all security considerations for your specific environment.
#
set -e

# Default values
INTERVAL=5
RESULT_DIR="./results"
DOMAIN_ENDPOINT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --endpoint)
      DOMAIN_ENDPOINT="$2"
      shift
      shift
      ;;
    --interval)
      INTERVAL="$2"
      shift
      shift
      ;;
    --result-dir)
      RESULT_DIR="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if domain endpoint is provided
if [ -z "${DOMAIN_ENDPOINT}" ]; then
  echo "Error: OpenSearch domain endpoint is required. Use --endpoint parameter."
  exit 1
fi

# Create results directory if it doesn't exist
mkdir -p "${RESULT_DIR}"

# Generate timestamp for this monitoring session
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "Starting OpenSearch cluster monitoring (Ctrl+C to stop)"
echo "Endpoint: ${DOMAIN_ENDPOINT}"
echo "Interval: ${INTERVAL} seconds"
echo "Results will be saved to ${RESULT_DIR}"

# Function to check if jq is installed
check_jq() {
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq to use this script."
    echo "You can install it using: sudo apt-get install jq (Ubuntu/Debian) or sudo yum install jq (CentOS/RHEL)"
    exit 1
  fi
}

# Check for jq
check_jq

# Start monitoring loop
while true; do
  CURRENT_TIME=$(date +%Y-%m-%d_%H:%M:%S)
  
  echo "Collecting metrics at ${CURRENT_TIME}"
  
  # Cluster health
  echo "Collecting cluster health..."
  curl -s -u admin:Admin123! --insecure "${DOMAIN_ENDPOINT}/_cluster/health" | \
    jq '. + {"timestamp": "'"${CURRENT_TIME}"'"}' >> "${RESULT_DIR}/cluster_health_${TIMESTAMP}.json"
  
  # Node stats
  echo "Collecting node stats..."
  curl -s -u admin:Admin123! --insecure "${DOMAIN_ENDPOINT}/_nodes/stats" | \
    jq '. + {"timestamp": "'"${CURRENT_TIME}"'"}' >> "${RESULT_DIR}/node_stats_${TIMESTAMP}.json"
  
  # Index stats
  echo "Collecting index stats..."
  curl -s -u admin:Admin123! --insecure "${DOMAIN_ENDPOINT}/_stats" | \
    jq '. + {"timestamp": "'"${CURRENT_TIME}"'"}' >> "${RESULT_DIR}/index_stats_${TIMESTAMP}.json"
  
  # Cat indices for a quick overview
  echo "Collecting indices overview..."
  curl -s -u admin:Admin123! --insecure "${DOMAIN_ENDPOINT}/_cat/indices?format=json" | \
    jq '. + [{"timestamp": "'"${CURRENT_TIME}"'"}]' >> "${RESULT_DIR}/cat_indices_${TIMESTAMP}.json"
  
  # Cat shards for shard allocation
  echo "Collecting shard allocation..."
  curl -s -u admin:Admin123! --insecure "${DOMAIN_ENDPOINT}/_cat/shards?format=json" | \
    jq '. + [{"timestamp": "'"${CURRENT_TIME}"'"}]' >> "${RESULT_DIR}/cat_shards_${TIMESTAMP}.json"
  
  echo "Metrics collected at ${CURRENT_TIME}"
  echo "Waiting ${INTERVAL} seconds for next collection..."
  echo ""
  
  sleep "${INTERVAL}"
done
