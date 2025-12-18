#!/bin/bash

source coder-infra.env

# Create secret (or retrieve existing)
if ! aws secretsmanager describe-secret --secret-id coder/database-password --region $AWS_REGION &>/dev/null; then
  DB_PASSWORD=$(openssl rand -base64 24)
  aws secretsmanager create-secret \
    --name coder/database-password \
    --secret-string "$DB_PASSWORD" \
    --region $AWS_REGION \
    --description "Coder RDS PostgreSQL password"
  echo "Created secret"
else
  echo "Secret already exists"
  DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id coder/database-password \
    --region $AWS_REGION \
    --query 'SecretString' --output text)
fi
