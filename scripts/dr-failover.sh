#!/bin/bash
set -e

# Default values
PRI_DOMAIN=""
DR_DOMAIN=""
PRI_REGION=""
DR_REGION=""
OWNER_ID=""
DOMAIN_ENDPOINT_DR=""
RESULT_DIR="./results"

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
if [ -z "$PRI_DOMAIN" ] || [ -z "$DR_DOMAIN" ] || [ -z "$PRI_REGION" ] || [ -z "$DR_REGION" ] || [ -z "$DOMAIN_ENDPOINT_DR" ] || [ -z "$DOMAIN_ENDPOINT_PRI" ]; then
  echo "Error: Required parameters missing."
  echo "Usage: $0 --pri-domain <primary-domain> --dr-domain <dr-domain> --pri-region <primary-region> --dr-region <dr-region> --dr-endpoint <dr-endpoint> --pri-endpoint <primary-endpoint> [--result-dir <result-directory>]"
  exit 1
fi

# Create results directory if it doesn't exist
mkdir -p "$RESULT_DIR"
LOG_FILE="$RESULT_DIR/dr-failover-$(date +%Y%m%d-%H%M%S).log"

echo "Starting DR failover testing suite..." | tee -a "$LOG_FILE"
echo "Primary Domain: $PRI_DOMAIN" | tee -a "$LOG_FILE"
echo "DR Domain: $DR_DOMAIN" | tee -a "$LOG_FILE"
echo "Primary Region: $PRI_REGION" | tee -a "$LOG_FILE"
echo "DR Region: $DR_REGION" | tee -a "$LOG_FILE"
echo "Primary Endpoint: $DOMAIN_ENDPOINT_PRI" | tee -a "$LOG_FILE"
echo "DR Endpoint: $DOMAIN_ENDPOINT_DR" | tee -a "$LOG_FILE"
echo "Results directory: $RESULT_DIR" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Test 1: Data Integrity Validation
echo "=========================================" | tee -a "$LOG_FILE"
echo "Running DR Test: Data Integrity Validation" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"

echo "Creating test index in primary region..." | tee -a "$LOG_FILE"

# Create test index with sample data
curl -X PUT "$DOMAIN_ENDPOINT_PRI/dr-test-index" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{
        "settings": {
            "number_of_shards": 4,
            "number_of_replicas": 1
        }
    }'

echo "" | tee -a "$LOG_FILE"
echo "Inserting test documents..." | tee -a "$LOG_FILE"

# Insert test documents
for i in {1..100}; do
    curl -X POST "$DOMAIN_ENDPOINT_PRI/dr-test-index/_doc/$i" \
        -H "Content-Type: application/json" \
        -u "admin:Admin123!" \
        -k \
        -d '{
            "id": '"$i"',
            "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
            "message": "DR test document '"$i"'"
        }' > /dev/null 2>&1
    
    if [ $((i % 20)) -eq 0 ]; then
        echo "Inserted $i documents..." | tee -a "$LOG_FILE"
    fi
done

echo "Inserted 100 documents in primary region" | tee -a "$LOG_FILE"

# Wait for replication
echo "Waiting for replication (60 seconds)..." | tee -a "$LOG_FILE"
sleep 60

# Verify document count in secondary
PRIMARY_COUNT=$(curl -s "$DOMAIN_ENDPOINT_PRI/dr-test-index/_count" \
    -u "admin:Admin123!" \
    -k | jq '.count')

SECONDARY_COUNT=$(curl -s "$DOMAIN_ENDPOINT_DR/dr-test-index/_count" \
    -u "admin:Admin123!" \
    -k | jq '.count')

echo "Primary document count: $PRIMARY_COUNT" | tee -a "$LOG_FILE"
echo "Secondary document count: $SECONDARY_COUNT" | tee -a "$LOG_FILE"

if [ "$PRIMARY_COUNT" -eq "$SECONDARY_COUNT" ]; then
    echo "✓ Data integrity test passed: $PRIMARY_COUNT documents replicated" | tee -a "$LOG_FILE"
else
    echo "✗ Data integrity test failed: Primary=$PRIMARY_COUNT, Secondary=$SECONDARY_COUNT" | tee -a "$LOG_FILE"
fi

# Test 2: Replication Lag Measurement
echo "" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "Running DR Test: Replication Lag Measurement" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"

# Create lag test index if it doesn't exist
curl -X PUT "$DOMAIN_ENDPOINT_PRI/lag-test" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{
        "settings": {
            "number_of_shards": 1,
            "number_of_replicas": 1
        }
    }' > /dev/null 2>&1

# Wait for index creation to replicate
sleep 10

# Insert timestamped document in primary
TIMESTAMP=$(date -u +%s%3N)
echo "Inserting timestamped document with timestamp: $TIMESTAMP" | tee -a "$LOG_FILE"

curl -X POST "$DOMAIN_ENDPOINT_PRI/lag-test/_doc" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{
        "timestamp": '"$TIMESTAMP"',
        "test": "replication-lag"
    }' > /dev/null 2>&1

# Poll secondary until document appears
START_TIME=$(date +%s)
echo "Polling secondary for document..." | tee -a "$LOG_FILE"

while true; do
    RESULT=$(curl -s "$DOMAIN_ENDPOINT_DR/lag-test/_search" \
        -H "Content-Type: application/json" \
        -u "admin:Admin123!" \
        -k \
        -d '{
            "query": {
                "match": {
                    "timestamp": '"$TIMESTAMP"'
                }
            }
        }' | jq '.hits.total.value')
    
    if [ "$RESULT" -gt 0 ]; then
        END_TIME=$(date +%s)
        LAG=$((END_TIME - START_TIME))
        echo "Replication lag: $LAG seconds" | tee -a "$LOG_FILE"
        break
    fi
    
    # Check if we've been waiting too long (2 minutes)
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - START_TIME)) -gt 120 ]; then
        echo "Timeout waiting for replication. Lag > 120 seconds." | tee -a "$LOG_FILE"
        break
    fi
    
    sleep 1
done

# Test 3: Simulated Failover
echo "" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "Running DR Test: Simulated Failover" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"

# Stop replication for test index
echo "Stopping replication for dr-test-index..." | tee -a "$LOG_FILE"
curl -X POST "$DOMAIN_ENDPOINT_DR/_plugins/_replication/dr-test-index/_stop" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{}' > /dev/null 2>&1

# Make secondary writable
echo "Making secondary cluster writable..." | tee -a "$LOG_FILE"
curl -XPUT "$DOMAIN_ENDPOINT_DR/_cluster/settings" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{
        "persistent": {
            "cluster.blocks.read_only": false
        }
    }' > /dev/null 2>&1

# Test write to secondary
echo "Testing write to secondary cluster..." | tee -a "$LOG_FILE"
FAILOVER_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
curl -X POST "$DOMAIN_ENDPOINT_DR/dr-test-index/_doc" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{
        "timestamp": "'"$FAILOVER_TIMESTAMP"'",
        "status": "failover-successful"
    }' > /dev/null 2>&1

# Verify the document was written
sleep 5
FAILOVER_DOC=$(curl -s "$DOMAIN_ENDPOINT_DR/dr-test-index/_search" \
    -H "Content-Type: application/json" \
    -u "admin:Admin123!" \
    -k \
    -d '{
        "query": {
            "match": {
                "status": "failover-successful"
            }
        }
    }' | jq '.hits.total.value')

if [ "$FAILOVER_DOC" -gt 0 ]; then
    echo "✓ Failover simulation completed successfully" | tee -a "$LOG_FILE"
else
    echo "✗ Failover simulation failed - could not write to secondary cluster" | tee -a "$LOG_FILE"
fi

# Final status
echo "" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "DR Failover Testing Summary" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "1. Data Integrity: $([ "$PRIMARY_COUNT" -eq "$SECONDARY_COUNT" ] && echo "PASSED" || echo "FAILED")" | tee -a "$LOG_FILE"
echo "2. Replication Lag: $LAG seconds" | tee -a "$LOG_FILE"
echo "3. Failover Simulation: $([ "$FAILOVER_DOC" -gt 0 ] && echo "PASSED" || echo "FAILED")" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "DR failover testing completed. Results and logs saved to $RESULT_DIR" | tee -a "$LOG_FILE"
