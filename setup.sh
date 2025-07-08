#!/bin/bash
set -e

# OpenSearch Performance and Resilience Testing Framework Setup Script
# This script helps set up the environment for running OpenSearch benchmarks and tests

# Default values
PRI_REGION="us-east-1"
DR_REGION="us-west-2"
STACK_NAME="opensearch-benchmark"
DR_STACK_NAME="opensearch-benchmark-dr"

# Print banner
echo "============================================================"
echo "  OpenSearch Performance and Resilience Testing Framework"
echo "============================================================"
echo ""

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check for AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured or invalid."
    echo "Please run 'aws configure' to set up your credentials."
    exit 1
fi

echo "AWS credentials verified successfully."
echo ""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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
    --stack-name)
      STACK_NAME="$2"
      shift
      shift
      ;;
    --dr-stack-name)
      DR_STACK_NAME="$2"
      shift
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --pri-region     Primary AWS region (default: us-east-1)"
      echo "  --dr-region      DR AWS region (default: us-west-2)"
      echo "  --stack-name     Primary CloudFormation stack name (default: opensearch-benchmark)"
      echo "  --dr-stack-name  DR CloudFormation stack name (default: opensearch-benchmark-dr)"
      echo "  --help           Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

echo "Setup Configuration:"
echo "- Primary Region: $PRI_REGION"
echo "- DR Region: $DR_REGION"
echo "- Primary Stack Name: $STACK_NAME"
echo "- DR Stack Name: $DR_STACK_NAME"
echo ""

# Check if templates exist
if [ ! -f "templates/opensearch-benchmark-cfn.yaml" ] || [ ! -f "templates/opensearch-benchmark-dr.yaml" ]; then
    echo "Error: CloudFormation templates not found in the templates directory."
    echo "Please make sure you're running this script from the root of the repository."
    exit 1
fi

# Check if scripts are executable
echo "Making scripts executable..."
chmod +x scripts/*.sh
echo "Scripts are now executable."
echo ""

# Validate CloudFormation templates
echo "Validating CloudFormation templates..."
aws cloudformation validate-template --template-body file://templates/opensearch-benchmark-cfn.yaml > /dev/null
echo "Primary template validated successfully."
aws cloudformation validate-template --template-body file://templates/opensearch-benchmark-dr.yaml > /dev/null
echo "DR template validated successfully."
echo ""

# Create results directory
echo "Creating results directory..."
mkdir -p results
echo "Results directory created."
echo ""

echo "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Deploy the primary stack:"
echo "   aws cloudformation create-stack \\"
echo "     --stack-name $STACK_NAME \\"
echo "     --template-body file://templates/opensearch-benchmark-cfn.yaml \\"
echo "     --capabilities CAPABILITY_IAM \\"
echo "     --region $PRI_REGION"
echo ""
echo "2. After the primary stack is created, deploy the DR stack with the outputs from the primary stack."
echo "   See README.md for detailed instructions."
echo ""
echo "3. Run benchmarks and tests using the scripts in the scripts directory."
echo ""
echo "For more information, refer to the README.md file."
