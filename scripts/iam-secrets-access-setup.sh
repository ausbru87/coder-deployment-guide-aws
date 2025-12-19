#!/bin/bash

source coder-infra.env

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IAM policy (or skip if exists)
if ! aws iam get-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CoderSecretsAccess &>/dev/null; then
  cat <<EOF > /tmp/coder-secrets-policy.json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ],
    "Resource": "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:coder/*"
  }]
}
EOF

  aws iam create-policy \
    --policy-name CoderSecretsAccess \
    --policy-document file:///tmp/coder-secrets-policy.json
  echo "Created IAM policy"
else
  echo "IAM policy already exists"
fi

# Create IAM role for Pod Identity (or skip if exists)
if ! aws iam get-role --role-name CoderSecretsRole &>/dev/null; then
  cat <<EOF > /tmp/coder-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "pods.eks.amazonaws.com"
    },
    "Action": ["sts:AssumeRole", "sts:TagSession"]
  }]
}
EOF

  aws iam create-role \
    --role-name CoderSecretsRole \
    --assume-role-policy-document file:///tmp/coder-trust-policy.json

  aws iam attach-role-policy \
    --role-name CoderSecretsRole \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CoderSecretsAccess
  echo "Created IAM role"
else
  echo "IAM role already exists"
fi

# Create coder namespace (required for Pod Identity association)
kubectl create namespace coder --dry-run=client -o yaml | kubectl apply -f -

# Create Pod Identity association (or skip if exists)
EXISTING_ASSOC=$(aws eks list-pod-identity-associations \
  --cluster-name $CLUSTER_NAME \
  --namespace coder \
  --service-account coder \
  --region $AWS_REGION \
  --query 'associations[0].associationId' --output text 2>/dev/null)

if [ -z "$EXISTING_ASSOC" ] || [ "$EXISTING_ASSOC" = "None" ]; then
  aws eks create-pod-identity-association \
    --cluster-name $CLUSTER_NAME \
    --namespace coder \
    --service-account coder \
    --role-arn arn:aws:iam::${ACCOUNT_ID}:role/CoderSecretsRole \
    --region $AWS_REGION
  echo "Created Pod Identity association"
else
  echo "Pod Identity association already exists"
fi
