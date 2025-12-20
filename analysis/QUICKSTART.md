# Coder on AWS - Quick Start Guide

This is a condensed version of the full deployment guide. For detailed information, see [DEPLOYMENT_ANALYSIS.md](./DEPLOYMENT_ANALYSIS.md).

---

## What You're Deploying

A production-ready Coder deployment on AWS with:
- Kubernetes (EKS) for container orchestration
- PostgreSQL (RDS) for Coder database
- Redis (ElastiCache) for caching
- AI capabilities via LiteLLM (AWS Bedrock + optional GCP Vertex AI)
- Auto-scaling via Karpenter
- Custom workspace images for Claude Code and Goose AI

**Deployment Time:** 60-90 minutes
**Estimated Cost:** $800-1,200/month for <10 concurrent users

---

## Prerequisites Checklist

Before starting, ensure you have:

### AWS Account
- [ ] AWS account with admin access
- [ ] AWS CLI v2 installed and configured
- [ ] Access to us-west-2 region
- [ ] EC2 instance quotas sufficient (check limits)
- [ ] AWS Bedrock access enabled in us-west-2

### Local Tools
- [ ] Terraform >= 1.0
- [ ] kubectl (latest)
- [ ] Helm 3.x
- [ ] Docker Desktop
- [ ] git

### External Services
- [ ] GitHub account (for OAuth)
- [ ] Valid email for Let's Encrypt SSL
- [ ] Domain name with DNS access (or use CloudFlare)

### Credentials to Prepare
- [ ] AWS access keys
- [ ] GitHub OAuth app (create during deployment)
- [ ] GCP service account key (optional, for Vertex AI)

---

## Quick Start Steps

### 1. Clone and Initialize (5 min)

```bash
# Clone repository
git clone <your-repo-url>
cd coder-aws-deployment

# Initialize submodule
git submodule update --init --recursive
```

### 2. Create S3 Backend (5 min)

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://my-coder-terraform-state --region us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-coder-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

### 3. Deploy Infrastructure (40 min)

Navigate to each directory in order and run:

```bash
# For each component:
cd ai.coder.com/infra/aws/us-west-2/<component>

# Create backend.tfvars
cat > backend.tfvars <<EOF
bucket = "my-coder-terraform-state"
key    = "us-west-2/<component>/terraform.tfstate"
region = "us-west-2"
encrypt = true
EOF

# Initialize and apply
terraform init -backend-config=backend.tfvars
terraform apply
```

**Deploy in this order:**
1. **vpc** (~10 min) - VPC, subnets, NAT gateway
2. **eks** (~20 min) - EKS cluster and node groups
3. **rds** (~10 min) - PostgreSQL database
4. **redis** (~5 min) - Redis cache
5. **ecr** (~2 min) - Container registry

**Save important outputs:**
```bash
# After each deployment, save outputs
terraform output -json > outputs.json
```

### 4. Mirror Coder Image (5 min)

```bash
# Get ECR repository URL from ecr outputs
ECR_REPO=$(terraform output -raw repository_url)

# Login to ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin $ECR_REPO

# Mirror Coder image
docker pull ghcr.io/coder/coder-preview:latest
docker tag ghcr.io/coder/coder-preview:latest $ECR_REPO/coder-preview:latest
docker push $ECR_REPO/coder-preview:latest
```

### 5. Deploy Kubernetes Apps (25 min)

Deploy in order:

```bash
cd ai.coder.com/infra/aws/us-west-2/k8s/<app>
terraform init -backend-config=backend.tfvars
terraform apply
```

**Deploy these apps:**
1. **cert-manager** (~3 min) - SSL certificate management
2. **lb-controller** (~3 min) - AWS Load Balancer integration
3. **ebs-controller** (~3 min) - EBS volume provisioning
4. **karpenter** (~3 min) - Node auto-scaling
5. **metrics-server** (~2 min) - Resource metrics
6. **coder-server** (~5 min) - Coder control plane
7. **coder-ws** (~3 min) - Workspace provisioners
8. **litellm** (~5 min) - AI model proxy

### 6. Configure DNS (10 min)

```bash
# Get Load Balancer hostname
kubectl get svc coder -n coder -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Create DNS records (via your DNS provider):
# coder.your-domain.com -> NLB hostname
# *.coder.your-domain.com -> NLB hostname
```

### 7. Create GitHub OAuth App (5 min)

1. Go to GitHub Settings → Developer Settings → OAuth Apps → New OAuth App
2. Fill in:
   - Name: `Coder Deployment`
   - Homepage URL: `https://coder.your-domain.com`
   - Callback URL: `https://coder.your-domain.com/api/v2/users/oauth2/github/callback`
3. Save Client ID and Secret

**Update Coder configuration** with GitHub OAuth credentials (redeploy coder-server with updated terraform.tfvars)

### 8. Access Coder (5 min)

```bash
# Wait for DNS to propagate
dig coder.your-domain.com

# Access Coder UI
open https://coder.your-domain.com

# Login with GitHub OAuth
# First user becomes admin
```

### 9. Create Test Workspace (5 min)

1. Click "Create Workspace"
2. Select template (e.g., "Build from Scratch w/ Claude")
3. Configure resources (2-4 vCPU, 4-8 GB)
4. Click "Create"
5. Wait for workspace to start
6. Click "Terminal" or "VS Code"

---

## Verification Checklist

After deployment, verify:

```bash
# Check all pods are running
kubectl get pods -A

# Check Coder Server
kubectl get pods -n coder -l app=coder

# Check Provisioners
kubectl get pods -n coder -l app=coder-provisioner

# Check LiteLLM
kubectl get pods -n litellm -l app=litellm

# Check Load Balancer
kubectl get svc -n coder
```

**Expected pod counts:**
- Coder Server: 2 pods
- Provisioners: 6 pods
- LiteLLM: 4 pods
- Karpenter: 1 pod
- cert-manager: 3 pods

---

## Common Issues

### Issue: Terraform state lock error
**Solution:** Delete lock in DynamoDB or use `-lock=false` flag

### Issue: EKS cluster takes too long
**Solution:** Normal, EKS takes 15-20 minutes to provision

### Issue: DNS not resolving
**Solution:** Wait for DNS propagation (up to 24 hours, usually 5-10 minutes)

### Issue: Workspace fails to start
**Solution:** Check provisioner logs: `kubectl logs -n coder -l app=coder-provisioner`

### Issue: Image pull errors
**Solution:** Verify ECR image exists: `aws ecr describe-images --repository-name coder-preview --region us-west-2`

---

## Scaling for Production

### For 10-15 concurrent users:
```bash
kubectl scale deployment coder-provisioner-default -n coder --replicas=8
```

### For 15-20 concurrent users:
```bash
kubectl scale deployment coder-provisioner-default -n coder --replicas=10
kubectl scale deployment litellm -n litellm --replicas=6
```

### For 20-30 concurrent users:
```bash
kubectl scale deployment coder-provisioner-default -n coder --replicas=12
kubectl scale deployment litellm -n litellm --replicas=8
```

---

## Cleanup

To destroy all resources:

```bash
# Delete in reverse order
cd ai.coder.com/infra/aws/us-west-2

# Delete K8s apps first
for app in litellm coder-ws coder-server metrics-server karpenter ebs-controller lb-controller cert-manager; do
  cd k8s/$app
  terraform destroy -auto-approve
  cd ../..
done

# Delete infrastructure
for component in ecr redis rds eks vpc; do
  cd $component
  terraform destroy -auto-approve
  cd ..
done
```

**Manual cleanup:**
- Delete S3 backend bucket
- Remove DNS records
- Delete GitHub OAuth app

---

## Next Steps

1. **Create workspace templates** for your team
2. **Invite users** via Coder UI
3. **Set up monitoring** (Prometheus + Grafana)
4. **Review security** settings and IAM roles
5. **Read full documentation** in [DEPLOYMENT_ANALYSIS.md](./DEPLOYMENT_ANALYSIS.md)

---

## Getting Help

- **Full Documentation:** [DEPLOYMENT_ANALYSIS.md](./DEPLOYMENT_ANALYSIS.md)
- **Coder Documentation:** https://coder.com/docs
- **ai.coder.com Submodule:** See `ai.coder.com/README.md`
- **Architecture Guide:** `ai.coder.com/docs/workshops/ARCHITECTURE.md`
- **Incident Runbook:** `ai.coder.com/docs/workshops/INCIDENT_RUNBOOK.md`

---

**Quick Start Version:** 1.1
**Last Updated:** November 16, 2025
**Region:** us-west-2 (Oregon)
