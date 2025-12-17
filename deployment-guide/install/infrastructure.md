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

## VPC and Networking

Create a VPC with public and private subnets across multiple availability zones:

```bash
# Set variables
export AWS_REGION=us-west-2
export CLUSTER_NAME=coder-cluster

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
- VPC with CIDR `10.0.0.0/16`
- Public subnets (for load balancers)
- Private subnets (for nodes and RDS)
- NAT Gateway (for outbound traffic from private subnets)
- Internet Gateway

Verify:

```bash
# Verify VPC created
aws ec2 describe-vpcs --filters "Name=tag:eksctl.cluster.k8s.io/v1alpha1/cluster-name,Values=$CLUSTER_NAME"

# Verify pod identity agent is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent

# Verify vpc-cni pods are healthy
kubectl get pods -n kube-system -l k8s-app=aws-node
```

## Security Groups

### RDS Security Group

Create a security group for RDS that allows PostgreSQL from EKS nodes:

```bash
# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.vpcId' --output text)

# Create RDS security group
RDS_SG=$(aws ec2 create-security-group \
  --group-name coder-rds-sg \
  --description "Allow PostgreSQL from EKS" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

# Get EKS cluster security group
EKS_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

# Allow inbound PostgreSQL from EKS
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $EKS_SG

echo "RDS Security Group: $RDS_SG"
```

## EKS Node Groups

Create three node groups per the [architecture](../architecture/diagrams.md):

### coder-system (coderd)

```bash
eksctl create nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name coder-system \
  --node-type m7i.large \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 2 \
  --node-private-networking \
  --node-labels "coder.com/node-type=system"
```

### coder-prov (provisioners)

```bash
eksctl create nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name coder-prov \
  --node-type c7i.2xlarge \
  --nodes 2 \
  --nodes-min 0 \
  --nodes-max 2 \
  --node-private-networking \
  --node-labels "coder.com/node-type=provisioner"
```

### coder-ws (workspaces)

```bash
eksctl create nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name coder-ws \
  --node-type m7i.12xlarge \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 20 \
  --node-private-networking \
  --node-labels "coder.com/node-type=workspace"
```

### Verify

```bash
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl get nodes -L coder.com/node-type
```

## RDS PostgreSQL

### Create DB Subnet Group

```bash
# Get private subnet IDs (eksctl tags them with 'Private')
PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*Private*" \
  --query 'Subnets[].SubnetId' --output text)

aws rds create-db-subnet-group \
  --db-subnet-group-name coder-db-subnet \
  --db-subnet-group-description "Coder RDS subnets" \
  --subnet-ids $PRIVATE_SUBNETS
```

### Store Password in Secrets Manager

```bash
DB_PASSWORD=$(openssl rand -base64 24)

aws secretsmanager create-secret \
  --name coder/database-password \
  --secret-string "$DB_PASSWORD" \
  --description "Coder RDS PostgreSQL password"
```

### Create Database

```bash
aws rds create-db-instance \
  --db-instance-identifier coder-db \
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
```

Wait for the database to be available (~10-15 minutes):

```bash
aws rds wait db-instance-available --db-instance-identifier coder-db
```

Get the endpoint:

```bash
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier coder-db \
  --query 'DBInstances[0].Endpoint.Address' --output text)
echo "RDS Endpoint: $RDS_ENDPOINT"
```

## ACM Certificate

Request a certificate for your domain:

```bash
export CODER_DOMAIN=coder.example.com

CERT_ARN=$(aws acm request-certificate \
  --domain-name $CODER_DOMAIN \
  --validation-method DNS \
  --query 'CertificateArn' --output text)

echo "Certificate ARN: $CERT_ARN"
```

### DNS Validation

Get the validation record:

```bash
aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
```

Create the validation record in Route 53:

```bash
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name $CODER_DOMAIN \
  --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)

# Get validation record details
VALIDATION=$(aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord')
RECORD_NAME=$(echo $VALIDATION | jq -r '.Name')
RECORD_VALUE=$(echo $VALIDATION | jq -r '.Value')

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
```

Wait for validation (~2-5 minutes):

```bash
aws acm wait certificate-validated --certificate-arn $CERT_ARN
echo "Certificate validated"
```

## Verification

Confirm all resources are ready:

```bash
# EKS cluster
kubectl get nodes

# RDS
aws rds describe-db-instances --db-instance-identifier coder-db \
  --query 'DBInstances[0].DBInstanceStatus'

# ACM certificate
aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.Status'
```

Expected output:
- Nodes: `Ready` status
- RDS: `available`
- ACM: `ISSUED`

## Environment Variables Summary

Save these for the next step:

```bash
cat <<EOF
CLUSTER_NAME=$CLUSTER_NAME
RDS_ENDPOINT=$RDS_ENDPOINT
CERT_ARN=$CERT_ARN
CODER_DOMAIN=$CODER_DOMAIN
EOF
```

To retrieve the database password later:

```bash
aws secretsmanager get-secret-value \
  --secret-id coder/database-password \
  --query 'SecretString' --output text
```

## Next Steps

Proceed to [Coder Installation](index.md).
