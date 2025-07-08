# OpenSearch Performance and Resilience Testing Framework

This repository contains a comprehensive framework for setting up, benchmarking, and testing the resilience of OpenSearch deployments on AWS. It includes CloudFormation templates for deploying OpenSearch domains in both primary and disaster recovery (DR) configurations, along with scripts for performance benchmarking, resilience testing, and cross-region replication.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Setup Instructions](#setup-instructions)
  - [Primary Region Setup](#primary-region-setup)
  - [Disaster Recovery (DR) Setup](#disaster-recovery-dr-setup)
- [Running Tests](#running-tests)
  - [Performance Benchmarks](#performance-benchmarks)
  - [Resilience Tests](#resilience-tests)
  - [DR Failover Tests](#dr-failover-tests)
- [Monitoring](#monitoring)
- [Cleanup](#cleanup)
- [CloudWatch Metrics](#cloudwatch-metrics)
- [Monitoring Metrics and Visualizations](#monitoring-metrics-and-visualizations)
  - [Performance Metrics Visualizations](#performance-metrics-visualizations)
  - [Resilience Test Visualizations](#resilience-test-visualizations)
- [Contributing](#contributing)
- [License](#license)

## Overview

This framework allows you to:

1. Deploy OpenSearch domains in AWS using CloudFormation templates
2. Run performance benchmarks to evaluate throughput, latency, and resource utilization
3. Test resilience by simulating node failures and observing recovery
4. Set up cross-region replication for disaster recovery
5. Test DR failover scenarios
6. Monitor key metrics through CloudWatch and custom scripts

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Python 3.6 or higher
- opensearch-benchmark tool installed (`pip install opensearch-benchmark`)
- jq for JSON processing (`apt-get install jq` or `yum install jq`)

## Repository Structure

```
opensearch-benchmark/
├── templates/                  # CloudFormation templates
│   ├── opensearch-benchmark-cfn.yaml  # Primary region template
│   └── opensearch-benchmark-dr.yaml   # DR region template
├── scripts/                    # Testing and utility scripts
│   ├── run-benchmark.sh        # Performance benchmark script
│   ├── resilience-test.sh      # Resilience testing script
│   ├── monitor-cluster.sh      # Cluster monitoring script
│   ├── crr-setup.sh            # Cross-region replication setup
│   ├── dr-failover.sh          # DR failover testing
│   └── crr-delete.sh           # Clean up cross-region replication
├── images/                     # Performance and resilience test visualizations
│   └── README.md               # Instructions for adding images
├── README.md                   # This file
├── LICENSE                     # Apache License 2.0
├── CONTRIBUTING.md             # Contribution guidelines
├── CODE_OF_CONDUCT.md          # Code of conduct
├── .gitignore                  # Git configuration
├── setup.sh                    # Environment setup helper
└── cleanup.sh                  # Resource cleanup helper
```

## Setup Instructions

### Primary Region Setup

1. Configure AWS CLI with your credentials:

```bash
aws configure
```

2. Set up variables for your deployment:

```bash
PRI_REGION="us-east-1"
DR_REGION="us-west-2"
```

3. Deploy the primary OpenSearch benchmark environment:

```bash
aws cloudformation create-stack \
  --stack-name opensearch-benchmark \
  --template-body file://templates/opensearch-benchmark-cfn.yaml \
  --capabilities CAPABILITY_IAM \
  --region $PRI_REGION
```

4. Wait for the stack to complete deployment (typically 15-20 minutes):

```bash
aws cloudformation wait stack-create-complete \
  --stack-name opensearch-benchmark \
  --region $PRI_REGION
```

5. Get the endpoint URL and other outputs from the primary stack:

```bash
PRIMARY_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name opensearch-benchmark \
  --query 'Stacks[0].Outputs[?OutputKey==`OpenSearchDomainEndpoint`].OutputValue' \
  --region $PRI_REGION \
  --output text)

PRIMARY_ARN=$(aws opensearch describe-domain \
  --domain-name benchmark-domain \
  --query 'DomainStatus.ARN' \
  --region $PRI_REGION \
  --output text)

VPC_PRI=$(aws cloudformation describe-stacks \
  --stack-name opensearch-benchmark \
  --query 'Stacks[0].Outputs[?OutputKey==`VPCIdPri`].OutputValue' \
  --region $PRI_REGION \
  --output text)

BENCHMARK_INSTANCE_IP=$(aws cloudformation describe-stacks \
  --stack-name opensearch-benchmark \
  --query 'Stacks[0].Outputs[?OutputKey==`BenchmarkInstancePublicIP`].OutputValue' \
  --region $PRI_REGION \
  --output text)

echo "Primary OpenSearch Endpoint: $PRIMARY_ENDPOINT"
echo "Primary OpenSearch ARN: $PRIMARY_ARN"
echo "Primary VPC ID: $VPC_PRI"
echo "Benchmark Instance IP: $BENCHMARK_INSTANCE_IP"
```

6. Connect to the EC2 instance using AWS EC2 Instance Connect or SSH:

```bash
# Using EC2 Instance Connect (in AWS Console)
# Navigate to EC2 > Instances > Select your instance > Connect > EC2 Instance Connect

# Or using SSH if you configured a key pair
# ssh -i your-key.pem ec2-user@$BENCHMARK_INSTANCE_IP
```

### Disaster Recovery (DR) Setup

1. Deploy the DR stack in the secondary region:

```bash
aws cloudformation create-stack \
  --stack-name opensearch-benchmark-dr \
  --template-body file://templates/opensearch-benchmark-dr.yaml \
  --parameters \
    ParameterKey=PrimaryDomainEndpoint,ParameterValue=$PRIMARY_ENDPOINT \
    ParameterKey=PrimaryRegion,ParameterValue=$PRI_REGION \
    ParameterKey=PrimaryDomainARN,ParameterValue=$PRIMARY_ARN \
    ParameterKey=PrimaryVPCId,ParameterValue=$VPC_PRI \
  --capabilities CAPABILITY_IAM \
  --region $DR_REGION
```

2. Wait for the DR stack to complete deployment:

```bash
aws cloudformation wait stack-create-complete \
  --stack-name opensearch-benchmark-dr \
  --region $DR_REGION
```

3. Create a route in the primary VPC to enable communication with the DR VPC:

```bash
VPC_PEERING_ID=$(aws cloudformation describe-stacks \
  --stack-name opensearch-benchmark-dr \
  --query 'Stacks[0].Outputs[?OutputKey==`VPCPeeringConnectionID`].OutputValue' \
  --output text \
  --region $DR_REGION)

aws ec2 create-route \
  --route-table-id $(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_PRI" "Name=association.main,Values=true" \
    --query 'RouteTables[0].RouteTableId' \
    --output text \
    --region $PRI_REGION) \
  --destination-cidr-block 10.1.0.0/16 \
  --vpc-peering-connection-id $VPC_PEERING_ID \
  --region $PRI_REGION
```

4. Get the DR domain endpoint and instance IP:

```bash
DR_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name opensearch-benchmark-dr \
  --query 'Stacks[0].Outputs[?OutputKey==`OpenSearchDomainEndpoint`].OutputValue' \
  --region $DR_REGION \
  --output text)

DR_INSTANCE_IP=$(aws cloudformation describe-stacks \
  --stack-name opensearch-benchmark-dr \
  --query 'Stacks[0].Outputs[?OutputKey==`BenchmarkInstancePublicIP`].OutputValue' \
  --region $DR_REGION \
  --output text)

echo "DR OpenSearch Endpoint: $DR_ENDPOINT"
echo "DR Instance IP: $DR_INSTANCE_IP"
```

5. Connect to the DR EC2 instance and set up cross-region replication:

```bash
# Using EC2 Instance Connect (in AWS Console)
# Navigate to EC2 > Instances > Select your DR instance > Connect > EC2 Instance Connect

# Then run the CRR setup script
./scripts/crr-setup.sh \
  --pri-domain benchmark-domain \
  --dr-domain benchmark-domain-dr \
  --pri-region $PRI_REGION \
  --dr-region $DR_REGION \
  --owner-id $(aws sts get-caller-identity --query 'Account' --output text)
```

## Running Tests

### Performance Benchmarks

Run performance benchmarks on the primary OpenSearch domain:

```bash
./scripts/run-benchmark.sh --endpoint https://$PRIMARY_ENDPOINT --workload geonames
```

Available options:
- `--endpoint`: OpenSearch domain endpoint (required)
- `--workload`: Benchmark workload to use (default: geonames)
- `--result-dir`: Directory to store results (default: ./results)

### Resilience Tests

Test resilience by simulating node failures while running benchmarks:

```bash
./scripts/resilience-test.sh \
  --domain benchmark-domain \
  --region $PRI_REGION \
  --endpoint https://$PRIMARY_ENDPOINT
```

Available options:
- `--domain`: OpenSearch domain name (required)
- `--region`: AWS region (required)
- `--endpoint`: OpenSearch domain endpoint (required)
- `--result-dir`: Directory to store results (default: ./results)

### DR Failover Tests

Test disaster recovery failover scenarios:

```bash
./scripts/dr-failover.sh \
  --pri-domain benchmark-domain \
  --dr-domain benchmark-domain-dr \
  --pri-region $PRI_REGION \
  --dr-region $DR_REGION \
  --pri-endpoint https://$PRIMARY_ENDPOINT \
  --dr-endpoint https://$DR_ENDPOINT
```

Available options:
- `--pri-domain`: Primary domain name (required)
- `--dr-domain`: DR domain name (required)
- `--pri-region`: Primary region (required)
- `--dr-region`: DR region (required)
- `--pri-endpoint`: Primary domain endpoint (required)
- `--dr-endpoint`: DR domain endpoint (required)
- `--result-dir`: Directory to store results (default: ./results)

## Monitoring

Monitor your OpenSearch cluster during tests:

```bash
./scripts/monitor-cluster.sh --endpoint https://$PRIMARY_ENDPOINT --interval 10
```

Available options:
- `--endpoint`: OpenSearch domain endpoint (required)
- `--interval`: Monitoring interval in seconds (default: 5)
- `--result-dir`: Directory to store results (default: ./results)

## Cleanup

1. Delete cross-region replication configuration:

```bash
./scripts/crr-delete.sh \
  --pri-domain benchmark-domain \
  --dr-domain benchmark-domain-dr \
  --pri-region $PRI_REGION \
  --dr-region $DR_REGION \
  --pri-endpoint https://$PRIMARY_ENDPOINT \
  --dr-endpoint https://$DR_ENDPOINT
```

2. Remove the VPC peering route:

```bash
aws ec2 delete-route \
  --route-table-id $(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_PRI" "Name=association.main,Values=true" \
    --query 'RouteTables[0].RouteTableId' \
    --output text \
    --region $PRI_REGION) \
  --destination-cidr-block 10.1.0.0/16 \
  --region $PRI_REGION
```

3. Delete the CloudFormation stacks:

```bash
# Delete DR stack first
aws cloudformation delete-stack --stack-name opensearch-benchmark-dr --region $DR_REGION

# Wait for DR stack deletion to complete
aws cloudformation wait stack-delete-complete --stack-name opensearch-benchmark-dr --region $DR_REGION

# Delete primary stack
aws cloudformation delete-stack --stack-name opensearch-benchmark --region $PRI_REGION
```

## CloudWatch Metrics

To review performance metrics in CloudWatch:

1. Access the AWS CloudWatch console in your region
2. Navigate to Metrics → All metrics
3. Find the "ES" namespace
4. Select your domain name (benchmark-domain)

Key metrics to monitor:

### Cluster Health Metrics
- ClusterStatus.yellow - Cluster in yellow state
- ClusterStatus.red - Cluster in red state
- Nodes - Number of nodes in cluster
- MasterReachableFromNode - Master node connectivity

### Performance Metrics
- CPUUtilization - CPU usage percentage
- JVMMemoryPressure - JVM heap memory usage
- SearchLatency - Average search request latency
- IndexingLatency - Average indexing request latency
- SearchRate - Search requests per second
- IndexingRate - Indexing requests per second

### Storage Metrics
- FreeStorageSpace - Available disk space

### Request Metrics
- 2xx, 3xx, 4xx, 5xx - HTTP response codes

### Critical Thresholds to Watch
- CPU Utilization: > 80% sustained
- JVM Memory Pressure: > 85%
- Storage Utilization: > 85%

## Monitoring Metrics and Visualizations

This repository includes reference images that demonstrate key metrics during benchmark and resilience tests. These images provide visual insights into OpenSearch performance characteristics and behavior during node failures.

### Performance Metrics Visualizations

The `images` directory contains visualizations of key performance metrics:

1. **CPU and Memory Utilization** - Shows CPU usage patterns during benchmark tests
2. **JVM Memory Pressure and Master JVM Memory Pressure** - Displays memory pressure metrics for JVM
3. **Indexing Latency and Search Latency** - Shows latency metrics for indexing and search operations
4. **Indexing Rate and Search Rate** - Displays throughput metrics for indexing and search operations
5. **Free Storage Space** - Shows available storage space during benchmark tests

### Resilience Test Visualizations

The following visualizations demonstrate OpenSearch behavior during node failure simulation:

1. **Cluster Green, Yellow and Red State** - Shows cluster state transitions during node failure
2. **Master Reachable from Node, Nodes** - Displays node connectivity metrics during failure tests
3. **4xx and 5xx Errors** - Shows HTTP error rates during resilience tests

These visualizations help in understanding:
- How OpenSearch performance metrics change under load
- How the cluster responds to node failures
- Recovery patterns after simulated failures
- Impact of node failures on client requests

> **Note:** To add these images to your repository, extract them from the "OpenSearch benchmark setup & monitoring.docx" document and place them in the `images` directory. See the README.md file in the images directory for detailed instructions.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.
