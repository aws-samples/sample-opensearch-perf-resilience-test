# Security Improvements

> **DISCLAIMER**: This code is provided as a sample for educational and testing purposes only. Users must perform their own security review and due diligence before deploying any code to production environments. The security improvements outlined in this document represent a baseline set of practices but may not address all security considerations for your specific environment.

This document outlines the security improvements.

## Overview of Security Issues Addressed

1. **Security Groups Documentation and Controls**
   - Clear descriptions to all security group rules
   - Restricted SSH access to specific CIDR blocks instead of 0.0.0.0/0
   - Implemented explicit egress rules instead of allowing unrestricted outbound traffic

2. **VPC Configuration Strengthening**
   - VPC Flow Logs for network traffic monitoring
   - Disabled automatic public IP assignment in subnets (MapPublicIpOnLaunch: false)

3. **OpenSearch Domain Security**
   - Enabled logging and audit logging for OpenSearch domains
   - Restricted access policies to specific IAM roles instead of wildcard principals
   - Maintained encryption at rest and in transit
   - For more information on OpenSearch security best practices, see: https://opensearch.org/docs/latest/security/index/ and https://docs.aws.amazon.com/opensearch-service/latest/developerguide/security.html

4. **Shell Scripting Practices**
   - Proper quoting around all variables to prevent command injection
   - Improved error handling and validation
   - Descriptive comments and usage information

## Detailed Changes

### CloudFormation Templates

#### Security Groups Improvements

```yaml
# Before
BenchmarkSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: Security group for benchmark EC2 instance
    VpcId: !Ref VPC
    SecurityGroupIngress:
      - IpProtocol: tcp
        FromPort: 22
        ToPort: 22
        CidrIp: 0.0.0.0/0
```

```yaml
# After
BenchmarkSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: Security group for benchmark EC2 instance
    VpcId: !Ref VPC
    SecurityGroupIngress:
      - IpProtocol: tcp
        FromPort: 22
        ToPort: 22
        CidrIp: !Ref AllowedSSHCIDR
        Description: "Allows SSH access from specified CIDR range for administration"
    SecurityGroupEgress:
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 0.0.0.0/0
        Description: "Allows HTTPS outbound traffic for package downloads and API calls"
      - IpProtocol: tcp
        FromPort: 80
        ToPort: 80
        CidrIp: 0.0.0.0/0
        Description: "Allows HTTP outbound traffic for package downloads"
```

#### EC2 Instance Connect Support

```yaml
# Added EC2 Instance Connect Support
BenchmarkSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: Security group for benchmark EC2 instance
    VpcId: !Ref VPC
    SecurityGroupIngress: !If
      - EnableEC2InstanceConnect
      - - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: !Ref AllowedSSHCIDR
          Description: "Allows SSH access from specified CIDR range for administration"
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 18.206.107.24/29
          Description: "Allows SSH access from EC2 Instance Connect (us-east-1)"
        # Additional regions included in template
      - - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: !Ref AllowedSSHCIDR
          Description: "Allows SSH access from specified CIDR range for administration"
```

#### VPC Flow Logs Addition

```yaml
# Added VPC Flow Logs
VPCFlowLog:
  Type: AWS::EC2::FlowLog
  Properties:
    DeliverLogsPermissionArn: !GetAtt VPCFlowLogsRole.Arn
    LogDestinationType: cloud-watch-logs
    LogGroupName: !Sub "/${AWS::StackName}/vpc-flow-logs"
    ResourceId: !Ref VPC
    ResourceType: VPC
    TrafficType: ALL
```

#### OpenSearch Logging Configuration

```yaml
# Added OpenSearch Logging
OpenSearchLogGroup:
  Type: AWS::Logs::LogGroup
  Properties:
    LogGroupName: !Sub "/aws/opensearch/${OpenSearchDomainName}"
    RetentionInDays: 30

# Added to OpenSearch Domain Properties
LogPublishingOptions:
  ES_APPLICATION_LOGS:
    CloudWatchLogsLogGroupArn: !GetAtt OpenSearchLogGroup.Arn
    Enabled: true
  AUDIT_LOGS:
    CloudWatchLogsLogGroupArn: !GetAtt OpenSearchLogGroup.Arn
    Enabled: true
  INDEX_SLOW_LOGS:
    CloudWatchLogsLogGroupArn: !GetAtt OpenSearchLogGroup.Arn
    Enabled: true
  SEARCH_SLOW_LOGS:
    CloudWatchLogsLogGroupArn: !GetAtt OpenSearchLogGroup.Arn
    Enabled: true
```

### Shell Script Improvements

#### Variable Quoting

```bash
# Before
if [ -z $DOMAIN_ENDPOINT ]; then
  echo "Error: Could not retrieve OpenSearch domain endpoint"
  exit 1
fi
```

```bash
# After
if [ -z "${DOMAIN_ENDPOINT}" ]; then
  echo "Error: Could not retrieve OpenSearch domain endpoint"
  exit 1
fi
```

#### Command Substitution Safety

```bash
# Before
NODE_COUNT=$(echo $NODE_IDS | wc -w)
```

```bash
# After
NODE_COUNT=$(echo "${NODE_IDS}" | wc -w)
```

#### Improved Error Handling

```bash
# Before
MAINTENANCE_ID=$(aws opensearch start-domain-maintenance \
  --domain-name $OPENSEARCH_DOMAIN \
  --region $AWS_REGION \
  --action REBOOT_NODE \
  --node-id $SELECTED_NODE_ID \
  --query 'MaintenanceId' \
  --output text)
```

```bash
# After
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
```

## Security Best Practices Implemented

1. **Principle of Least Privilege**
   - Security groups now follow the principle of least privilege, allowing only necessary traffic
   - IAM roles have been scoped to only the required permissions
   - For more information on AWS IAM least privilege best practices, see: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege and https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started-reduce-permissions.html

2. **Defense in Depth**
   - Added multiple layers of security controls (network, access, logging)
   - Implemented both preventive (security groups) and detective (logging) controls

3. **Secure Configuration**
   - Disabled automatic public IP assignment
   - Maintained encryption settings for data at rest and in transit
   - Restricted access to specific IAM roles

4. **Monitoring and Logging**
   - Added VPC Flow Logs for network traffic monitoring
   - Enabled OpenSearch application, audit, and slow logs
   - Improved script logging for better troubleshooting and security analysis

5. **Secure Coding Practices**
   - Properly quoted all variables in shell scripts
   - Added input validation for command-line arguments
   - Improved error handling and reporting

## How to Use the Secure Templates and Scripts

1. For CloudFormation templates:
   ```
   aws cloudformation create-stack --stack-name opensearch-benchmark \
     --template-body file://templates/opensearch-benchmark-cfn.yaml \
     --parameters ParameterKey=AllowedSSHCIDR,ParameterValue=YOUR_IP_CIDR \
                  ParameterKey=AllowEC2InstanceConnect,ParameterValue=true
   ```

   The `AllowEC2InstanceConnect` parameter (default: true) enables SSH access from EC2 Instance Connect IP ranges, allowing you to connect to your instances directly from the AWS Management Console without needing to open SSH access to your specific IP.

2. For shell scripts:
   ```
   ./scripts/run-benchmark.sh --endpoint https://your-opensearch-endpoint
   ```

## Security Considerations

The security improvements outlined in this document implements several AWS security best practices. The changes focus on:

1. Better documentation and tighter controls for security groups
2. Strengthened VPC configuration with flow logs and proper subnet settings
3. Enhanced OpenSearch domain security with logging and audit capabilities
4. Improved shell scripting practices to prevent potential vulnerabilities

While these changes significantly improve the security posture of the OpenSearch performance and resilience testing infrastructure, security is an ongoing process. Users should:

- Regularly review and update security configurations as best practices evolve
- Consider additional security controls specific to their environment and use case
- Perform regular security assessments and penetration testing
- Stay informed about security updates for all components in the infrastructure

For production deployments, additional security measures beyond those implemented here may be necessary based on your organization's security requirements and compliance standards.
