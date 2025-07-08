#!/bin/bash
set -e

# Default values
RESULT_DIR="./results"
WORKLOAD="geonames"
TEST_PROCEDURE="default"
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
    --workload)
      WORKLOAD="$2"
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
if [ -z "$DOMAIN_ENDPOINT" ]; then
  echo "Error: OpenSearch domain endpoint is required. Use --endpoint parameter."
  exit 1
fi

# Create results directory if it doesn't exist
mkdir -p "$RESULT_DIR"

echo "Running benchmark with:"
echo "- Workload: $WORKLOAD"
echo "- Test procedure: $TEST_PROCEDURE"
echo "- Results directory: $RESULT_DIR"
echo ""

echo "Using OpenSearch endpoint: $DOMAIN_ENDPOINT"

# Run the benchmark
opensearch-benchmark execute-test \
  --target-hosts=$DOMAIN_ENDPOINT \
  --client-options="use_ssl:true,verify_certs:false,basic_auth_user:admin,basic_auth_password:Admin123!" \
  --workload=$WORKLOAD \
  --workload-params="number_of_replicas: 1","number_of_shards: 4" \
  --pipeline=benchmark-only \
  --results-file=$RESULT_DIR/benchmark-results-$(date +%Y%m%d-%H%M%S).json \
  --kill-running-processes

echo "Benchmark completed. Results saved to $RESULT_DIR"
