#!/bin/bash
set -e

# OpenSearch Performance and Resilience Testing Framework Cleanup Script
# This script helps clean up AWS resources created by the framework

# Default values
PRI_REGION="us-east-1"
DR_REGION="us-west-2"
STACK_NAME="opensearch-benchmark"
DR_STACK_NAME="opensearch-benchmark-dr"
SKIP_CONFIRMATION=false

# Print banner
echo "============================================================"
echo "  OpenSearch Performance and Resilience Testing Framework"
echo "                      Cleanup Script"
echo "============================================================"
echo ""
echo "WARNING: This script will delete all resources created by the framework."
echo "         This action cannot be undone."
echo ""

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

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
    --force)
      SKIP_CONFIRMATION=true
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
      echo "  --force          Skip confirmation prompt"
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

echo "Cleanup Configuration:"
echo "- Primary Region: $PRI_REGION"
echo "- DR Region: $DR_REGION"
echo "- Primary Stack Name: $STACK_NAME"
echo "- DR Stack Name: $DR_STACK_NAME"
echo ""

# Confirm deletion
if [ "$SKIP_CONFIRMATION" = false ]; then
    read -p "Are you sure you want to proceed with cleanup? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

# Step 1: Check if DR stack exists and get VPC peering connection ID
echo "Checking for DR stack..."
if aws cloudformation describe-stacks --stack-name $DR_STACK_NAME --region $DR_REGION &> /dev/null; then
    echo "DR stack found. Getting VPC peering connection ID..."
    
    VPC_PEERING_ID=$(aws cloudformation describe-stacks \
        --stack-name $DR_STACK_NAME \
        --query 'Stacks[0].Outputs[?OutputKey==`VPCPeeringConnectionID`].OutputValue' \
        --output text \
        --region $DR_REGION)
    
    if [ -n "$VPC_PEERING_ID" ]; then
        echo "VPC peering connection ID: $VPC_PEERING_ID"
    else
        echo "VPC peering connection ID not found in stack outputs."
    fi
else
    echo "DR stack not found. Skipping VPC peering cleanup."
fi

# Step 2: Check if primary stack exists and get VPC ID
echo "Checking for primary stack..."
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $PRI_REGION &> /dev/null; then
    echo "Primary stack found. Getting VPC ID..."
    
    VPC_PRI=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs[?OutputKey==`VPCIdPri`].OutputValue' \
        --output text \
        --region $PRI_REGION)
    
    if [ -n "$VPC_PRI" ]; then
        echo "Primary VPC ID: $VPC_PRI"
    else
        echo "Primary VPC ID not found in stack outputs."
    fi
else
    echo "Primary stack not found. Skipping VPC route cleanup."
fi

# Step 3: Remove VPC peering route if both IDs are found
if [ -n "$VPC_PEERING_ID" ] && [ -n "$VPC_PRI" ]; then
    echo "Removing VPC peering route..."
    
    ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_PRI" "Name=association.main,Values=true" \
        --query 'RouteTables[0].RouteTableId' \
        --output text \
        --region $PRI_REGION)
    
    if [ -n "$ROUTE_TABLE_ID" ] && [ "$ROUTE_TABLE_ID" != "None" ]; then
        echo "Route table ID: $ROUTE_TABLE_ID"
        
        # Delete the route
        aws ec2 delete-route \
            --route-table-id $ROUTE_TABLE_ID \
            --destination-cidr-block 10.1.0.0/16 \
            --region $PRI_REGION
        
        echo "VPC peering route deleted."
    else
        echo "Route table not found. Skipping route deletion."
    fi
else
    echo "Skipping VPC peering route deletion due to missing IDs."
fi

# Step 4: Delete DR stack
if aws cloudformation describe-stacks --stack-name $DR_STACK_NAME --region $DR_REGION &> /dev/null; then
    echo "Deleting DR stack..."
    aws cloudformation delete-stack --stack-name $DR_STACK_NAME --region $DR_REGION
    
    echo "Waiting for DR stack deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name $DR_STACK_NAME --region $DR_REGION
    
    echo "DR stack deleted successfully."
else
    echo "DR stack not found. Skipping deletion."
fi

# Step 5: Delete primary stack
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $PRI_REGION &> /dev/null; then
    echo "Deleting primary stack..."
    aws cloudformation delete-stack --stack-name $STACK_NAME --region $PRI_REGION
    
    echo "Primary stack deletion initiated."
    echo "Note: This may take 15-20 minutes to complete."
    echo "You can check the status in the AWS CloudFormation console."
else
    echo "Primary stack not found. Skipping deletion."
fi

echo ""
echo "Cleanup process initiated. Some resources may take time to delete."
echo "Please check the AWS CloudFormation console to confirm deletion completion."
