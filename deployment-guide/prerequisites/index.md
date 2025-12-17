# Prerequisites

Before deploying Coder on AWS, ensure you have the following in place.

## Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [AWS CLI](https://aws.amazon.com/cli/) | 2.x | AWS resource management |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | ±1 minor of EKS | Kubernetes management |
| [Helm](https://helm.sh/docs/intro/install/) | 3.5+ | Coder deployment |

Optional: [eksctl](https://eksctl.io/) for cluster creation, [jq](https://jqlang.github.io/jq/) for scripting.

Verify your setup:

```bash
aws sts get-caller-identity  # Confirms AWS auth
kubectl version --client
helm version
```

## AWS Account Access

Your IAM principal needs permissions to create/manage:

- **EKS** cluster and node groups
- **VPC** networking (subnets, security groups, NAT gateways)
- **RDS** PostgreSQL instance
- **ELB** (Network Load Balancer)
- **IAM** roles and policies (including `iam:PassRole`)

<details>
<summary>Example IAM policy (broad, for initial deployment)</summary>

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["eks:*", "ec2:*", "rds:*", "elasticloadbalancing:*",
               "iam:CreateRole", "iam:AttachRolePolicy", "iam:PutRolePolicy", "iam:PassRole"],
    "Resource": "*"
  }]
}
```

Scope down to least privilege after successful deployment.
</details>

## EKS Cluster

Create a cluster or use an existing one:

```bash
# Create with eksctl (if needed)
eksctl create cluster \
  --name coder-cluster \
  --region us-west-2 \
  --node-type t3.large \
  --nodes 3

# Configure kubectl
aws eks update-kubeconfig --name coder-cluster --region us-west-2

# Verify
kubectl get nodes
```

**Requirements:**
- Kubernetes 1.27+ (for longest support runway)
- Nodes: 2+ with at least 2 vCPU, 4 GB RAM each

## PostgreSQL Database

Coder requires PostgreSQL 13+. Create an RDS instance:

```bash
aws rds create-db-instance \
  --db-instance-identifier coder-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 15 \
  --db-name coder \
  --master-username coder \
  --master-user-password <secure-password> \
  --allocated-storage 20 \
  --vpc-security-group-ids <sg-id> \
  --db-subnet-group-name <subnet-group>
```

**Network connectivity:** RDS must be reachable from EKS nodes on port 5432.
Place both in the same VPC and configure security groups accordingly.

## Domain and TLS (Production)

For production, you need:
- A domain (e.g., `coder.example.com`)
- TLS certificate via [AWS Certificate Manager](https://aws.amazon.com/certificate-manager/) or cert-manager

## Network Requirements

| Direction | Port | Purpose |
|-----------|------|---------|
| Outbound | 443 | Container registries, Terraform providers |
| Inbound | 443 | User access to Coder UI/API |
| Inbound | 22 (optional) | Direct SSH to workspaces |

## Service Quotas

Check these quotas in your target region (Service Quotas console):
- EC2: Elastic IPs, NAT gateways, running instances
- EKS: Clusters per region
- RDS: DB instances

## Checklist

- [ ] AWS CLI configured (`aws sts get-caller-identity` works)
- [ ] kubectl and Helm installed
- [ ] EKS cluster running and accessible
- [ ] RDS PostgreSQL instance created
- [ ] Security groups allow EKS → RDS on port 5432
- [ ] Domain and TLS certificate ready (production)

## Next Steps

Proceed to [Installation](../install/index.md).
