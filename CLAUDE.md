# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a **step-by-step deployment guide** for Coder on AWS EKS, designed for 500 peak concurrent workspaces. It provides production-ready documentation with copy-paste commands for infrastructure setup and Coder installation.

**Target Audience:** DevOps engineers, platform teams, and Coder administrators deploying production Coder instances on AWS.

**Architecture:** EKS-based deployment with:
- Amazon EKS (4 dedicated node groups: system, coderd, provisioner, workspace)
- Amazon RDS PostgreSQL (multi-AZ)
- AWS Secrets Manager (via CSI Secrets Store with IRSA)
- Network Load Balancer with ACM certificates
- External provisioners for workspace management

## Repository Structure

```
.
├── deployment-guide/       # Main documentation
│   ├── prerequisites/      # Tool requirements, IAM permissions, quotas
│   ├── install/           # Infrastructure and Coder installation steps
│   │   ├── infrastructure.md  # VPC, EKS, RDS, ACM setup
│   │   └── coder.md          # Coder Helm deployment
│   ├── configuration/     # Post-install configuration
│   ├── troubleshooting/   # Common issues and solutions
│   └── AGENTS.md         # Instructions for AI assistants
├── scripts/              # Automation scripts for setup tasks
├── configs/              # Sample configuration files
├── cluster-config.yaml   # eksctl cluster configuration
├── decisions.md          # Technical decision log (e.g., IRSA vs Pod Identity)
└── README.md            # Entry point with quick links
```

## Documentation Philosophy

**Iterative, verifiable steps:** All documentation is designed to be executed incrementally with verification at each stage. Every section includes:
- Prerequisites
- Copy-paste commands (idempotent where possible)
- Verification steps
- Expected output

**Environment file pattern:** Uses `coder-infra.env` to persist variables across terminal sessions (e.g., `AWS_REGION`, `CLUSTER_NAME`, `RDS_ENDPOINT`, `CERT_ARN`).

**Source of truth hierarchy:**
1. Official Coder documentation for Coder behavior
2. Official AWS documentation for AWS services
3. `coder/docs` repository for structure and tone

## Common Commands

### Prerequisites Verification

```bash
# Verify all required tools are installed
aws --version           # AWS CLI 2.x
kubectl version --client  # kubectl ±1 minor of EKS
helm version            # Helm 3.5+
coder version           # Latest Coder CLI
eksctl version          # Latest eksctl

# Verify AWS credentials and region
aws sts get-caller-identity
source scripts/coder-infra.env
```

### Infrastructure Deployment

```bash
# Always source environment file first
source scripts/coder-infra.env

# Create EKS cluster with eksctl
eksctl create cluster -f cluster-config.yaml --without-nodegroup

# Create node groups (run in parallel with RDS provisioning)
eksctl create nodegroup --cluster $CLUSTER_NAME --name system --node-type t3.medium --nodes 3
eksctl create nodegroup --cluster $CLUSTER_NAME --name coder-coderd --node-type m7i.xlarge --nodes 2
eksctl create nodegroup --cluster $CLUSTER_NAME --name coder-provisioner --node-type c7i.2xlarge --nodes 1
eksctl create nodegroup --cluster $CLUSTER_NAME --name coder-workspace --node-type m7i.12xlarge --nodes 2

# Taint dedicated nodes (prevents non-Coder workloads)
kubectl taint nodes -l coder/node-type=coderd coder/node-type=coderd:NoSchedule
kubectl taint nodes -l coder/node-type=provisioner coder/node-type=provisioner:NoSchedule
kubectl taint nodes -l coder/node-type=workspace coder/node-type=workspace:NoSchedule

# Create RDS database (takes ~10-15 min)
aws rds create-db-instance --db-instance-identifier coder-db --engine postgres --db-instance-class db.m7i.large ...
aws rds wait db-instance-available --db-instance-identifier coder-db --region $AWS_REGION

# Request ACM certificate and validate via DNS
aws acm request-certificate --domain-name $CODER_DOMAIN --validation-method DNS
aws acm wait certificate-validated --certificate-arn $CERT_ARN --region $AWS_REGION
```

### Coder Installation

```bash
# Install Secrets Store CSI Driver and AWS Provider
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system --set syncSecret.enabled=true
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

# Install Coder via Helm
helm repo add coder-v2 https://helm.coder.com/v2
helm install coder coder-v2/coder --namespace coder --values configs/coder-values.yaml

# Deploy external provisioners
coder provisioner keys create eks-provisioner --tag scope=organization
kubectl create secret generic coder-provisioner-key --namespace coder --from-literal=key="<key>"
helm install coder-provisioner coder-v2/coder-provisioner --namespace coder --values provisioner-values.yaml
```

### Verification

```bash
# Verify infrastructure (use scripts/verify-aws-prereqs.sh)
kubectl get nodes -L coder/node-type
aws rds describe-db-instances --db-instance-identifier coder-db --query 'DBInstances[0].DBInstanceStatus'
aws acm describe-certificate --certificate-arn $CERT_ARN --query 'Certificate.Status'

# Verify Coder deployment
kubectl get pods -n coder
kubectl get svc coder -n coder
kubectl get secret coder-secrets -n coder

# Access Coder
curl -I https://$CODER_DOMAIN
```

## Key Architectural Decisions

**IRSA over Pod Identity:** This guide uses IRSA (IAM Roles for Service Accounts) instead of EKS Pod Identity due to better SDK compatibility with the CSI Secrets Store driver (see decisions.md:14).

**External provisioners:** Coderd runs with `CODER_PROVISIONER_DAEMONS=0`. External provisioner pods on dedicated nodes handle workspace provisioning (20 concurrent builds: 2 pods × 10 daemons each).

**Node isolation via taints:** Four dedicated node groups with taints ensure workload isolation:
- `system` (no taint): Kubernetes system components
- `coder-coderd` (tainted): Coder control plane (2 replicas, HA)
- `coder-provisioner` (tainted): Provisioner workloads (2 replicas)
- `coder-workspace` (tainted): Developer workspaces (2-20 nodes, auto-scaling)

**Secrets management:** AWS Secrets Manager + CSI Secrets Store driver syncs secrets to Kubernetes. Secrets created:
- `coder/database-url` — PostgreSQL connection string
- `coder/github-client-id` — GitHub OAuth (optional)
- `coder/github-client-secret` — GitHub OAuth (optional)
- `coder/github-allowed-orgs` — GitHub OAuth (optional)

## Working with This Repository

### When Editing Documentation

- **Match the tone of deployment-guide/AGENTS.md:** Clear, imperative steps with verification checkpoints
- **Work incrementally:** Propose small, testable changes (60-120 lines max)
- **Always include verification:** Commands, expected output, and common failure signals
- **Preserve idempotency:** Commands should be safe to re-run (use `--dry-run=client`, conditional checks, or AWS `UPSERT` operations)
- **Use environment file pattern:** All variables should be saved to `coder-infra.env` and loaded via `source`

### Testing Changes

```bash
# Validate markdown links
find deployment-guide -name "*.md" -exec markdown-link-check {} \;

# Test script syntax
shellcheck scripts/*.sh

# Verify eksctl config
eksctl create cluster -f cluster-config.yaml --dry-run
```

### Adding New Scripts

- Place in `scripts/` directory
- Make executable: `chmod +x scripts/new-script.sh`
- Source environment: `source coder-infra.env` at the top
- Include error handling and idempotency checks
- Document in the relevant deployment-guide section

### Capacity Planning Reference

| Users   | Provisioner Replicas | CODER_PROVISIONER_DAEMONS | Concurrent Builds |
|---------|---------------------|---------------------------|-------------------|
| <100    | 2 (default)         | 10 (default)              | 20                |
| 100-250 | 3                   | 10                        | 30                |
| 250-500 | 4                   | 10                        | 40                |

| Node Group | Instance Type | Min | Max | Purpose |
|------------|---------------|-----|-----|---------|
| system     | t3.medium     | 3   | 3   | Kubernetes system components |
| coderd     | m7i.xlarge    | 2   | 2   | Coder control plane (HA) |
| provisioner| c7i.2xlarge   | 1   | 2   | Workspace provisioning |
| workspace  | m7i.12xlarge  | 2   | 20  | Developer workspaces |

## Important Files

- **deployment-guide/install/infrastructure.md** — Complete AWS infrastructure setup (VPC, EKS, RDS, ACM)
- **deployment-guide/install/coder.md** — Coder installation via Helm with secrets management
- **deployment-guide/prerequisites/index.md** — Tool requirements, IAM permissions, service quotas
- **scripts/coder-infra.env** — Persistent environment variables (gitignored if it contains secrets)
- **cluster-config.yaml** — eksctl configuration for EKS cluster creation
- **decisions.md** — Technical decision log (especially IRSA vs Pod Identity)
- **deployment-guide/AGENTS.md** — Instructions for AI assistants working on this repo

## Known Limitations

- **No Terraform/IaC:** This guide uses imperative AWS CLI and eksctl commands for simplicity. For production IaC, see the ai.coder.com reference architecture.
- **Manual scaling:** Node groups use fixed sizes; no cluster autoscaler or Karpenter configured.
- **Single region:** This guide deploys a single-region architecture. Multi-region proxy setup not included.
- **GitHub OAuth default:** Uses GitHub for simplicity; production deployments should configure OIDC (Okta, Azure AD, etc.).

## Support

- Official Coder documentation: https://coder.com/docs
- Coder community Discord: https://coder.com/discord
- AWS EKS documentation: https://docs.aws.amazon.com/eks/
