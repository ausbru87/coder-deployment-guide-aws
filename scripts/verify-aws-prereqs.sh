#!/bin/bash

source coder-infra.env

# 1. EKS Nodes (should show 6 nodes across 3 groups)
kubectl get nodes -L coder.com/node-type

# 2. RDS (should show "available")
aws rds describe-db-instances --db-instance-identifier coder-db --region $AWS_REGION \
  --query 'DBInstances[0].DBInstanceStatus' --output text

# 3. ACM (should show "ISSUED")
aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION \
  --query 'Certificate.Status' --output text

# 4. Env file has all variables
cat coder-infra.env

