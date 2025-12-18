#!/bin/bash

source coder-infra.env

# Create RDS instance (or skip if exists)
if ! aws rds describe-db-instances --db-instance-identifier coder-db --region $AWS_REGION &>/dev/null; then
  aws rds create-db-instance \
    --db-instance-identifier coder-db \
    --region $AWS_REGION \
    --db-instance-class db.m7i.large \
    --engine postgres \
    --engine-version 15 \
    --db-name coder \
    --master-username coder \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage 100 \
    --storage-type gp3 \
    --vpc-security-group-ids $RDS_SG \
    --db-subnet-group-name coder-db-subnet \
    --no-publicly-accessible \
    --backup-retention-period 7 \
    --multi-az \
    --storage-encrypted
  echo "Creating RDS instance..."
else
  echo "RDS instance already exists"
fi
