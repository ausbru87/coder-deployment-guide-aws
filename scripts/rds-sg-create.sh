#!/bin/bash


source coder-infra.env

# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

# Create RDS security group (or get existing)
RDS_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=coder-rds-sg" "Name=vpc-id,Values=$VPC_ID" \
  --region $AWS_REGION \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

if [ "$RDS_SG" = "None" ] || [ -z "$RDS_SG" ]; then
  RDS_SG=$(aws ec2 create-security-group \
    --group-name coder-rds-sg \
    --description "Allow PostgreSQL from EKS" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' --output text)
  echo "Created RDS Security Group: $RDS_SG"
else
  echo "Using existing RDS Security Group: $RDS_SG"
fi

# Get EKS cluster security group
EKS_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

# Allow inbound PostgreSQL from EKS (idempotent - ignores if rule exists)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $EKS_SG \
  --region $AWS_REGION 2>/dev/null || echo "Ingress rule already exists"

# Save to env file (avoid duplicates)
grep -q "VPC_ID" coder-infra.env || echo "export VPC_ID=$VPC_ID" >> coder-infra.env
grep -q "RDS_SG" coder-infra.env || echo "export RDS_SG=$RDS_SG" >> coder-infra.env
grep -q "EKS_SG" coder-infra.env || echo "export EKS_SG=$EKS_SG" >> coder-infra.env

echo "RDS Security Group: $RDS_SG"

