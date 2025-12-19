# Infrastructure Setup

Create the AWS resources required for Coder.

> [!NOTE]
> Complete all [prerequisites](../prerequisites/index.md) before proceeding.

## Overview

This guide creates:

1. VPC with public and private subnets
2. Security groups
3. EKS cluster
4. RDS PostgreSQL database
5. ACM certificate

## Environment Setup

Create an environment file to store variables across sessions:

```bash
# Create environment file (edit these values for your deployment)
cat <<'EOF' > coder-infra.env
export AWS_REGION=us-west-2
export CLUSTER_NAME=coder-cluster
export CODER_DOMAIN=coder.example.com
EOF

# Source it
source coder-infra.env
```

> [!TIP]
> Run `source coder-infra.env` at the start of each terminal session to restore variables.

## VPC and Networking

Create a VPC with public and private subnets across multiple availability zones:

```bash
source coder-infra.env

# Create VPC and EKS cluster (creates subnets, NAT, IGW)
cat <<EOF > cluster-config.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
vpc:
  cidr: 10.0.0.0/16
autoModeConfig:
  enabled: false
iam:
  withOIDC: true
addons:
- name: vpc-cni
  version: latest
  resolveConflicts: overwrite
  useDefaultPodIdentityAssociations: true
- name: kube-proxy
  version: latest
  resolveConflicts: overwrite
- name: coredns
  version: latest
  resolveConflicts: overwrite
- name: eks-pod-identity-agent
  version: latest
EOF

eksctl create cluster -f cluster-config.yaml --without-nodegroup
```

This creates:

| Resource | Description |
|----------|-------------|
| **VPC** | CIDR `10.0.0.0/16` |
| **Public Subnets** | 3 subnets (one per AZ) for load balancers |
| **Private Subnets** | 3 subnets (one per AZ) for nodes and RDS |
| **Internet Gateway** | Public internet access |
| **NAT Gateway** | Outbound internet for private subnets |
| **Route Tables** | Public and private routing |
| **EKS Cluster** | Kubernetes control plane |
| **OIDC Provider** | IAM identity provider for IRSA/Pod Identity |
| **CloudWatch Log Group** | `/aws/eks/${CLUSTER_NAME}/cluster` |
| **IAM Roles** | Cluster service role, Pod Identity role for vpc-cni |
| **EKS Addons** | vpc-cni, kube-proxy, coredns, eks-pod-identity-agent |
| **Security Groups** | Cluster SG (control plane ↔ nodes) |

Verify:

```bash
# Verify VPC created
aws ec2 describe-vpcs --filters "Name=tag:eksctl.cluster.k8s.io/v1alpha1/cluster-name,Values=$CLUSTER_NAME"

# Verify addons are installed (pods won't run until node groups are created)
aws eks list-addons --cluster-name $CLUSTER_NAME --region $AWS_REGION
```

## Security Groups

### RDS Security Group

Create a security group for RDS that allows PostgreSQL from EKS nodes:

```bash
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
```

Verify:

```bash
aws ec2 describe-security-groups --group-ids $RDS_SG --region $AWS_REGION \
  --query 'SecurityGroups[0].IpPermissions'
```

## RDS PostgreSQL

### Create DB Subnet Group

```bash
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
```

### Store Password in Secrets Manager

```bash
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
```

### Create Database

```bash
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
```

Wait for the database to be available (~10-15 minutes):

```bash
source coder-infra.env

aws rds wait db-instance-available --db-instance-identifier coder-db --region $AWS_REGION
```

Get the endpoint:

```bash
source coder-infra.env

RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier coder-db \
  --region $AWS_REGION \
  --query 'DBInstances[0].Endpoint.Address' --output text)

# Save to env file
grep -q "RDS_ENDPOINT" coder-infra.env || echo "export RDS_ENDPOINT=$RDS_ENDPOINT" >> coder-infra.env

echo "RDS Endpoint: $RDS_ENDPOINT"
```

### Store Database URL in Secrets Manager

Create the full connection URL for Coder:

```bash
source coder-infra.env

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id coder/database-password \
  --region $AWS_REGION \
  --query 'SecretString' --output text)

DB_URL="postgres://coder:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/coder?sslmode=require"

# Create secret (or skip if exists)
if ! aws secretsmanager describe-secret --secret-id coder/database-url --region $AWS_REGION &>/dev/null; then
  aws secretsmanager create-secret \
    --name coder/database-url \
    --secret-string "$DB_URL" \
    --region $AWS_REGION \
    --description "Coder PostgreSQL connection URL"
  echo "Created database URL secret"
else
  echo "Database URL secret already exists"
fi
```

### Create IAM Role for Coder Secrets Access

Create an IAM role with Pod Identity for Coder to access Secrets Manager:

```bash
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
```

## EKS Node Groups

> [!TIP]
> Start RDS creation above, then run node groups in parallel while RDS provisions (~10-15 min).

Create four node groups per the [architecture](../architecture/diagrams.md):

### system (Kubernetes system components)

Small nodes for K8s system components (CoreDNS, kube-proxy, etc.). No taints—runs default workloads.

```bash
source coder-infra.env

eksctl create nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name system \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 3 \
  --node-private-networking
```

### coder-coderd (Coder control plane)

Dedicated nodes for coderd replicas. Tainted to prevent other workloads.

```bash
source coder-infra.env

eksctl create nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name coder-coderd \
  --node-type m7i.xlarge \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 2 \
  --node-private-networking \
  --node-labels "coder/node-type=coderd"
```

Taint the nodes to only allow coderd workloads:

```bash
kubectl taint nodes -l coder/node-type=coderd coder/node-type=coderd:NoSchedule
```

### coder-provisioner (external provisioners)

Dedicated nodes for Coder provisioner workloads. Tainted to isolate provisioning jobs.

```bash
source coder-infra.env

eksctl create nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name coder-provisioner \
  --node-type c7i.2xlarge \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 2 \
  --node-private-networking \
  --node-labels "coder/node-type=provisioner"
```

Taint the nodes to only allow provisioner workloads:

```bash
kubectl taint nodes -l coder/node-type=provisioner coder/node-type=provisioner:NoSchedule
```

### coder-workspace (workspaces)

Dedicated nodes for developer workspaces. Tainted to isolate workspace pods.

```bash
source coder-infra.env

eksctl create nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name coder-workspace \
  --node-type m7i.12xlarge \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 20 \
  --node-private-networking \
  --node-labels "coder/node-type=workspace"
```

Taint the nodes to isolate workspace workloads:

```bash
kubectl taint nodes -l coder/node-type=workspace coder/node-type=workspace:NoSchedule
```

### Verify

```bash
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl get nodes -L coder/node-type
```

## ACM Certificate

> [!NOTE]
> ACM certificates auto-renew. No cert-manager needed for MVP.

Request a certificate for your domain:

```bash
source coder-infra.env

# Check for existing certificate
CERT_ARN=$(aws acm list-certificates --region $AWS_REGION \
  --query "CertificateSummaryList[?DomainName=='$CODER_DOMAIN'].CertificateArn" --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" = "None" ]; then
  CERT_ARN=$(aws acm request-certificate \
    --domain-name $CODER_DOMAIN \
    --region $AWS_REGION \
    --validation-method DNS \
    --query 'CertificateArn' --output text)
  echo "Requested new certificate: $CERT_ARN"
else
  echo "Using existing certificate: $CERT_ARN"
fi

# Save to env file (avoid duplicates)
grep -q "CERT_ARN" coder-infra.env || echo "export CERT_ARN=$CERT_ARN" >> coder-infra.env
```

### DNS Validation

Get the validation record and create it in Route 53:

```bash
source coder-infra.env

# Check if already validated
CERT_STATUS=$(aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION \
  --query 'Certificate.Status' --output text)

if [ "$CERT_STATUS" = "ISSUED" ]; then
  echo "Certificate already validated"
else
  # Get hosted zone for base domain
  BASE_DOMAIN=$(echo $CODER_DOMAIN | cut -d. -f2-)
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name $BASE_DOMAIN \
    --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)

  # Get validation record details
  VALIDATION=$(aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord')
  RECORD_NAME=$(echo $VALIDATION | jq -r '.Name')
  RECORD_VALUE=$(echo $VALIDATION | jq -r '.Value')

  # Create/update validation record (UPSERT is idempotent)
  aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'$RECORD_NAME'",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$RECORD_VALUE'"}]
      }
    }]
  }'
  echo "Created validation record"
fi
```

Wait for validation (~2-5 minutes):

```bash
source coder-infra.env

aws acm wait certificate-validated --certificate-arn $CERT_ARN --region $AWS_REGION
echo "Certificate validated"
```

## Verification

Confirm all resources are ready:

```bash
source coder-infra.env

# 1. EKS Nodes (should show 6 nodes across 3 groups)
kubectl get nodes -L coder/node-type

# 2. RDS (should show "available")
aws rds describe-db-instances --db-instance-identifier coder-db --region $AWS_REGION \
  --query 'DBInstances[0].DBInstanceStatus' --output text

# 3. ACM (should show "ISSUED")
aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION \
  --query 'Certificate.Status' --output text

# 4. Env file has all variables
cat coder-infra.env
```

Expected output:
- Nodes: 6 nodes with `Ready` status (2 system, 2 provisioner, 2 workspace)
- RDS: `available`
- ACM: `ISSUED`
- Env file contains: `AWS_REGION`, `CLUSTER_NAME`, `CODER_DOMAIN`, `VPC_ID`, `RDS_SG`, `EKS_SG`, `RDS_ENDPOINT`, `CERT_ARN`

## Environment Variables Summary

All variables have been saved to `coder-infra.env`. View contents:

```bash
cat coder-infra.env
```

To retrieve the database password:

```bash
source coder-infra.env

aws secretsmanager get-secret-value \
  --secret-id coder/database-password \
  --region $AWS_REGION \
  --query 'SecretString' --output text
```

## Next Steps

Proceed to [Coder Installation](coder.md).
