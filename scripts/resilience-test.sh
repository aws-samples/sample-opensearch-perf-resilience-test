#!/bin/bash
set -e

# Default values
OPENSEARCH_DOMAIN=""
AWS_REGION=""
RESULT_DIR="./results"
DOMAIN_ENDPOINT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      OPENSEARCH_DOMAIN="$2"
      shift
      shift
      ;;
    --region)
      AWS_REGION="$2"
      shift
      shift
      ;;
    --endpoint)
      DOMAIN_ENDPOINT="$2"
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

# Check if required parameters are provided
if [ -z "${OPENSEARCH_DOMAIN}" ] || [ -z "${AWS_REGION}" ] || [ -z "${DOMAIN_ENDPOINT}" ]; then
  echo "Error: Required parameters missing."
  echo "Usage: $0 --domain <domain-name> --region <aws-region> --endpoint <domain-endpoint> [--result-dir <result-directory>]"
  exit 1
fi

# Create results directory if it doesn't exist
mkdir -p "${RESULT_DIR}"
LOG_FILE="${RESULT_DIR}/resilience-test-$(date +%Y%m%d-%H%M%S).log"

echo "" | tee -a "${LOG_FILE}"
echo "******* Starting Resiliency Test *******" | tee -a "${LOG_FILE}"
echo "Domain: ${OPENSEARCH_DOMAIN}" | tee -a "${LOG_FILE}"
echo "Region: ${AWS_REGION}" | tee -a "${LOG_FILE}"
echo "Endpoint: ${DOMAIN_ENDPOINT}" | tee -a "${LOG_FILE}"
echo "Results directory: ${RESULT_DIR}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

# Start benchmark in background
echo "Starting benchmark in background..." | tee -a "${LOG_FILE}"
opensearch-benchmark execute-test \
  --target-hosts="${DOMAIN_ENDPOINT}" \
  --client-options="use_ssl:true,verify_certs:false,basic_auth_user:admin,basic_auth_password:Admin123!" \
  --workload=nyc_taxis \
  --workload-params="number_of_replicas: 1","number_of_shards: 4" \
  --pipeline=benchmark-only \
  --results-file="${RESULT_DIR}/resilience-benchmark-results-$(date +%Y%m%d-%H%M%S).json" \
  --kill-running-processes > "${LOG_FILE}" 2>&1 &

# Store benchmark process ID
BENCHMARK_PID=$!
echo "Benchmark process ID: ${BENCHMARK_PID}" | tee -a "${LOG_FILE}"

# Wait for benchmark to warm up
echo "Waiting for benchmark to warm up (5 minutes)..." | tee -a "${LOG_FILE}"
sleep 300

# Function to get a random node ID from the domain
get_random_node_id() {
  # Get all node IDs using describe-domain-nodes
  NODE_IDS=$(aws opensearch describe-domain-nodes \
      --domain-name "${OPENSEARCH_DOMAIN}" \
      --region "${AWS_REGION}" \
      --query 'DomainNodesStatusList[?NodeType==`Data`].NodeId' \
      --output text)

  # Count the actual number of nodes
  NODE_COUNT=$(echo "${NODE_IDS}" | wc -w)
  if [ "${NODE_COUNT}" -eq 0 ]; then
      echo "No nodes found in domain ${OPENSEARCH_DOMAIN}" | tee -a "${LOG_FILE}"
      exit 1
  fi

  RANDOM_NODE=$((1 + RANDOM % NODE_COUNT))

  # Initialize variables
  COUNT=0
  SELECTED_NODE=""

  # Process space-separated string without array
  for node in ${NODE_IDS}; do
      COUNT=$((COUNT + 1))
      if [ "${COUNT}" -eq "${RANDOM_NODE}" ]; then
          SELECTED_NODE="${node}"
          break
      fi
  done

  # Return selected node ID
  echo "${SELECTED_NODE}"
}

# Get random node ID
SELECTED_NODE_ID=$(get_random_node_id)

if [ -z "${SELECTED_NODE_ID}" ]; then
    echo "Failed to get node ID" | tee -a "${LOG_FILE}"
    exit 1
fi

echo "Selected random node for restart: ${SELECTED_NODE_ID}" | tee -a "${LOG_FILE}"
echo "Node restart initiated" | tee -a "${LOG_FILE}"

# Initiate node restart using start-domain-maintenance
MAINTENANCE_ID=$(aws opensearch start-domain-maintenance \
  --domain-name "${OPENSEARCH_DOMAIN}" \
  --region "${AWS_REGION}" \
  --action REBOOT_NODE \
  --node-id "${SELECTED_NODE_ID}" \
  --query 'MaintenanceId' \
  --output text)

# Check if MAINTENANCE_ID was successfully obtained
if [ -z "${MAINTENANCE_ID}" ] || [ "${MAINTENANCE_ID}" == "None" ]; then
    echo "Failed to start domain maintenance. Exiting..." | tee -a "${LOG_FILE}"
    exit 1
fi

echo "Maintenance ID: ${MAINTENANCE_ID}" | tee -a "${LOG_FILE}"

# Monitor node restart status
echo "Monitoring node restart status..." | tee -a "${LOG_FILE}"
while true; do
  STATUS=$(aws opensearch get-domain-maintenance-status \
    --domain-name "${OPENSEARCH_DOMAIN}" \
    --maintenance-id "${MAINTENANCE_ID}" \
    --region "${AWS_REGION}" \
    --query 'Status' \
    --output text)

  echo "Current status: ${STATUS}" | tee -a "${LOG_FILE}"
  
  if [ "${STATUS}" == "COMPLETED" ]; then
    echo "Maintenance completed successfully" | tee -a "${LOG_FILE}"
    break
  fi
  sleep 60
done

# Let benchmark continue for a while after restart
echo "Continuing benchmark for 5 more minutes after node restart..." | tee -a "${LOG_FILE}"
sleep 300

# Stop benchmark
echo "Stopping benchmark..." | tee -a "${LOG_FILE}"
kill "${BENCHMARK_PID}"

# Wait for benchmark to finish
wait "${BENCHMARK_PID}" || true

echo "Resilience test completed. Results and logs saved to ${RESULT_DIR}" | tee -a "${LOG_FILE}"
