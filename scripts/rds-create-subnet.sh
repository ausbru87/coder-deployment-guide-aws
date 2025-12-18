#!/bin/bash

source coder-infra.env

# Get private subnet IDs
PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*Private*" \
  --region $AWS_REGION \
  --query 'Subnets[].SubnetId' --output text)

# Create subnet group (or skip if exists)
if ! aws rds describe-db-subnet-groups --db-subnet-group-name coder-db-subnet --region $AWS_REGION &>/dev/null; then
  aws rds create-db-subnet-group \
    --db-subnet-group-name coder-db-subnet \
    --db-subnet-group-description "Coder RDS subnets" \
    --subnet-ids $PRIVATE_SUBNETS \
    --region $AWS_REGION
  echo "Created DB subnet group"
else
  echo "DB subnet group already exists"
fi
