# AWS Prerequisites Verification Checklist

This checklist verifies that your AWS account is ready to deploy the Coder infrastructure.

**Target Region:** us-west-2 (Oregon)

---

## 1. AWS Account Access

- [ ] **AWS CLI configured and working**
  ```bash
  aws sts get-caller-identity
  ```
  Expected: Should return your account ID, user ARN, and user ID

- [ ] **Correct AWS region set to us-west-2**
  ```bash
  aws configure get region
  ```
  Expected: `us-west-2` (or set it: `aws configure set region us-west-2`)

---

## 2. IAM Permissions

Verify you have sufficient permissions to create resources:

- [ ] **Check EKS permissions**
  ```bash
  aws eks list-clusters --region us-west-2
  ```
  Expected: Should return empty list or existing clusters (no access denied error)

- [ ] **Check EC2 permissions**
  ```bash
  aws ec2 describe-vpcs --region us-west-2 --max-results 1
  ```
  Expected: Should return VPC list (can be empty)

- [ ] **Check RDS permissions**
  ```bash
  aws rds describe-db-instances --region us-west-2 --max-results 1
  ```
  Expected: Should return DB instances list (can be empty)

- [ ] **Check IAM permissions**
  ```bash
  aws iam list-roles --max-items 1
  ```
  Expected: Should return at least one role

- [ ] **Check S3 permissions**
  ```bash
  aws s3 ls
  ```
  Expected: Should list S3 buckets (can be empty)

- [ ] **Check ElastiCache permissions**
  ```bash
  aws elasticache describe-cache-clusters --region us-west-2 --max-records 1
  ```
  Expected: Should return cache clusters list (can be empty)

- [ ] **Check ECR permissions**
  ```bash
  aws ecr describe-repositories --region us-west-2 --max-results 1
  ```
  Expected: Should return repositories list (can be empty)

---

## 3. AWS Service Quotas

Check that you have sufficient quotas for the deployment:

### VPC Quotas

- [ ] **VPCs per region** (need: 1, can be 3 if multi-region)
  ```bash
  aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-F678F1CE \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 5 (default is 5)

- [ ] **Subnets per VPC** (need: 10+)
  ```bash
  aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-407747CB \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 200 (default is 200)

- [ ] **Elastic IPs** (need: 1 for NAT gateway)
  ```bash
  aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-0263D0A3 \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 5 (default is 5)

### EC2 Quotas

- [ ] **Running On-Demand t3.xlarge instances** (need: 3-10)
  ```bash
  aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-43DA4232 \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 10 vCPUs (t3.xlarge = 4 vCPUs each)

  Alternative check - see current usage:
  ```bash
  aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" "Name=instance-type,Values=t3.xlarge" \
    --region us-west-2 \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType]' \
    --output table
  ```

- [ ] **Running On-Demand m5.large instances** (need: 1 for RDS)
  ```bash
  aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-43DA4232 \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 2 vCPUs (m5.large = 2 vCPUs)

### EBS Quotas

- [ ] **EBS Storage (gp3)** (need: 500 GB+)
  ```bash
  aws service-quotas get-service-quota \
    --service-code ebs \
    --quota-code L-7A658B76 \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 1000 GB (default is 300 TiB)

- [ ] **EBS Snapshots per region**
  ```bash
  aws service-quotas get-service-quota \
    --service-code ebs \
    --quota-code L-309BACF6 \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 10000 (default is 10000)

### RDS Quotas

- [ ] **DB Instances**
  ```bash
  aws service-quotas get-service-quota \
    --service-code rds \
    --quota-code L-7B6409FD \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 40 (default is 40)

- [ ] **DB Storage (PostgreSQL)**
  ```bash
  aws service-quotas get-service-quota \
    --service-code rds \
    --quota-code L-7ADDB58A \
    --region us-west-2 \
    --query 'Quota.Value'
  ```
  Expected: >= 100 GB (default is 100000 GB)

### ElastiCache Quotas

- [ ] **Cache Clusters per region**
  ```bash
  aws service-quotas get-service-quota \
    --service-code elasticache \
    --quota-code L-47A9171B \
    --region us-west-2 \
    --query 'Quota.Value' 2>/dev/null || echo "50 (default)"
  ```
  Expected: >= 1 (default is 50)

---

## 4. AWS Bedrock Access

- [ ] **AWS Bedrock is available in us-west-2**
  ```bash
  aws bedrock list-foundation-models --region us-west-2 --query 'modelSummaries[?contains(modelId, `claude`)].modelId' --output table
  ```
  Expected: Should list Claude models (e.g., `anthropic.claude-v2`, `anthropic.claude-3-sonnet-20240229-v1:0`)

- [ ] **Claude models are enabled**
  ```bash
  aws bedrock list-foundation-models \
    --region us-west-2 \
    --by-provider anthropic \
    --query 'modelSummaries[*].[modelId,modelName]' \
    --output table
  ```
  Expected: Should show Anthropic Claude models

  If empty or access denied:
  - Go to AWS Console → Bedrock → Model access
  - Request access to Anthropic Claude models
  - Wait for approval (usually instant for most accounts)

---

## 5. Networking Verification

- [ ] **Available Availability Zones in us-west-2** (need: 3)
  ```bash
  aws ec2 describe-availability-zones \
    --region us-west-2 \
    --filters "Name=state,Values=available" \
    --query 'AvailabilityZones[*].ZoneName' \
    --output table
  ```
  Expected: At least 3 AZs (us-west-2a, us-west-2b, us-west-2c, us-west-2d)

- [ ] **Check for existing VPC conflicts**
  ```bash
  aws ec2 describe-vpcs \
    --region us-west-2 \
    --filters "Name=cidr,Values=10.0.0.0/16" \
    --query 'Vpcs[*].[VpcId,CidrBlock]' \
    --output table
  ```
  Expected: Should be empty (no VPC using 10.0.0.0/16)

  If not empty, you'll need to choose a different CIDR block for deployment

---

## 6. S3 Backend for Terraform State

- [ ] **S3 bucket name is available** (must be globally unique)
  ```bash
  # Try to create a test bucket (replace with your desired name)
  BUCKET_NAME="your-org-coder-terraform-state-usw2"
  aws s3 mb s3://${BUCKET_NAME} --region us-west-2 2>&1
  ```
  Expected: Success message or "bucket already owned by you"

  If bucket name taken, try a different name with your org prefix

- [ ] **DynamoDB available for state locking**
  ```bash
  aws dynamodb list-tables --region us-west-2 --max-items 1
  ```
  Expected: Should return table list (can be empty)

---

## 7. Container Registry (ECR)

- [ ] **Docker is installed and running locally**
  ```bash
  docker --version
  docker ps
  ```
  Expected: Docker version info and no errors on `docker ps`

- [ ] **Can authenticate to ECR**
  ```bash
  aws ecr get-login-password --region us-west-2 | head -c 20
  ```
  Expected: Should return first 20 chars of auth token (no errors)

---

## 8. Kubernetes Tools

- [ ] **kubectl installed**
  ```bash
  kubectl version --client
  ```
  Expected: Client version info

- [ ] **helm installed**
  ```bash
  helm version
  ```
  Expected: Helm version info (v3.x)

---

## 9. Cost Estimation Check

Run this to estimate current costs before deployment:

```bash
# Check current EC2 usage
echo "Current EC2 instances:"
aws ec2 describe-instances \
  --region us-west-2 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceType,State.Name]' \
  --output table

# Check current RDS usage
echo -e "\nCurrent RDS instances:"
aws rds describe-db-instances \
  --region us-west-2 \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine]' \
  --output table

# Check current EBS volumes
echo -e "\nCurrent EBS volumes:"
aws ec2 describe-volumes \
  --region us-west-2 \
  --query 'Volumes[*].[VolumeId,Size,VolumeType,State]' \
  --output table
```

**Expected monthly cost for Coder deployment:**
- Control plane only (us-west-2): $800-1,200/month for <10 users
- Additional costs scale with:
  - Number of concurrent workspaces
  - Workspace sizes (CPU/RAM)
  - Data transfer
  - EBS storage

---

## 10. DNS Provider Access (Optional but Recommended)

- [ ] **Domain name available**
  - Do you have a domain? ________________
  - DNS provider? (Route53, CloudFlare, etc.) ________________

- [ ] **If using Route53:**
  ```bash
  aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table
  ```
  Expected: List of hosted zones

---

## Summary Checklist

Before proceeding with deployment, ensure:

- [x] AWS CLI configured for us-west-2
- [x] IAM permissions verified (EKS, EC2, RDS, S3, IAM, ElastiCache, ECR)
- [x] Service quotas sufficient (VPC, EC2, EBS, RDS, ElastiCache)
- [x] AWS Bedrock Claude models accessible in us-west-2
- [x] 3+ Availability Zones available
- [x] S3 bucket name chosen for Terraform state
- [x] Docker, kubectl, helm installed locally
- [x] Domain name prepared (optional)

---

## Quick Verification Script

Save this as `verify-aws-prerequisites.sh`:

```bash
#!/bin/bash
set -e

echo "=== AWS Prerequisites Verification ==="
echo "Region: us-west-2"
echo ""

echo "1. AWS Account Info:"
aws sts get-caller-identity

echo -e "\n2. AWS Region:"
aws configure get region

echo -e "\n3. Availability Zones:"
aws ec2 describe-availability-zones --region us-west-2 --filters "Name=state,Values=available" --query 'AvailabilityZones[*].ZoneName'

echo -e "\n4. EC2 Quota (On-Demand Standard vCPUs):"
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A --region us-west-2 --query 'Quota.Value' 2>/dev/null || echo "Unable to fetch (may need quota API access)"

echo -e "\n5. VPC Quota:"
aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE --region us-west-2 --query 'Quota.Value' 2>/dev/null || echo "Unable to fetch"

echo -e "\n6. AWS Bedrock Claude Models:"
aws bedrock list-foundation-models --region us-west-2 --by-provider anthropic --query 'modelSummaries[*].modelId' 2>/dev/null || echo "Bedrock access not configured"

echo -e "\n7. Docker Status:"
docker --version && echo "Docker is running" || echo "Docker not found"

echo -e "\n8. Kubernetes Tools:"
kubectl version --client --short 2>/dev/null || echo "kubectl not found"
helm version --short 2>/dev/null || echo "helm not found"

echo -e "\n=== Verification Complete ==="
```

Run with:
```bash
chmod +x verify-aws-prerequisites.sh
./verify-aws-prerequisites.sh
```

---

**Last Updated:** November 16, 2025
**Region:** us-west-2 (Oregon)
