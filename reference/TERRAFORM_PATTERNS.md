# Coder AWS Deployment - Single Region Patterns

Production-ready Terraform infrastructure for deploying [Coder](https://coder.com) on Amazon Web Services with high availability and cost optimization.

## 🚀 Quick Start

Deploy Coder with high availability in **60 minutes**:

```bash
# 1. Clone repository
git clone git@github.com:ausbru87/coder-aws-deploy.git
cd coder-aws-deploy

# 2. Copy pattern file
cp terraform/patterns/sr-ha.tfvars terraform/my-deployment.tfvars

# 3. Configure required variables
vim terraform/my-deployment.tfvars
# Update: owner, base_domain, oidc_issuer_url, oidc_client_id, oidc_client_secret_arn

# 4. Deploy infrastructure
cd terraform
terraform init
terraform apply -var-file=my-deployment.tfvars
```

See the [Quick Start Guide](docs/getting-started/quickstart.md) for complete instructions.

## 📖 Documentation

Complete documentation is located in [`/docs/`](docs/README.md):

- **Getting Started:** [Architecture Overview](docs/getting-started/overview.md) | [Prerequisites](docs/getting-started/prerequisites.md) | [Quick Start](docs/getting-started/quickstart.md)
- **Deployment Patterns:** [SR-HA (Production)](docs/deployment-patterns/sr-ha/overview.md) | [SR-Simple (Dev/Test)](docs/deployment-patterns/sr-simple/overview.md)
- **Operations:** [Day 0 Deployment](docs/operations/day0-deployment.md) | [Day 2 Operations](docs/operations/day2-operations.md) | [Troubleshooting](docs/operations/troubleshooting.md)
- **Reference:** [Cost Estimation](docs/reference/cost-estimation.md) | [FAQ](docs/reference/faq.md)

## 🎯 Deployment Patterns

### SR-HA: Single Region High Availability (v1.0 ✅)

**Status:** Production-ready and validated

**Best for:** Production deployments, 100-500 users, 99.9% uptime

**Features:**
- 3 availability zones for HA
- 2+ coderd replicas with automatic failover
- Time-based auto-scaling (06:45-18:15 ET weekdays)
- Spot instances for workspace nodes (70% cost savings)
- Supports up to 3,000 concurrent workspaces

**Cost:** $2,500-4,000/month

[→ Read SR-HA Documentation](docs/deployment-patterns/sr-ha/overview.md)

### SR-Simple: Single Region Simple (v2.0 🚧)

**Status:** Planned for future release

**Best for:** Development/test environments, <20 users

**Features:**
- 1 availability zone
- 1 coderd replica
- Static capacity (no auto-scaling)
- On-demand instances only
- Supports up to 100 concurrent workspaces

**Cost:** $600-800/month

[→ Read SR-Simple Documentation](docs/deployment-patterns/sr-simple/overview.md)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Coder AWS Deployment                      │
│                                                              │
│  ┌────────────────────┐         ┌─────────────────────┐     │
│  │   Network (VPC)    │         │  Compute (EKS)      │     │
│  │                    │         │                     │     │
│  │ • 3 AZs            │────────▶│ • Control Nodes     │     │
│  │ • 5 Subnet Tiers   │         │ • Provisioner Nodes │     │
│  │ • NAT Gateways     │         │ • Workspace Nodes   │     │
│  │ • Load Balancer    │         │ • Time-Based Scale  │     │
│  └────────────────────┘         └─────────────────────┘     │
│           │                               │                  │
│           │                               │                  │
│           ▼                               ▼                  │
│  ┌────────────────────┐         ┌─────────────────────┐     │
│  │  Database (Aurora) │         │ Observability       │     │
│  │                    │         │                     │     │
│  │ • PostgreSQL 16.4  │         │ • CloudWatch Logs   │     │
│  │ • Serverless v2    │         │ • CloudWatch Metrics│     │
│  │ • Multi-AZ         │         │ • Container Insights│     │
│  │ • Auto-Scaling     │         │ • CloudTrail        │     │
│  └────────────────────┘         └─────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## 📦 What's Included

### Infrastructure Modules
- **VPC:** Multi-tier networking with 5 subnet types (public, control, provisioner, workspace, database)
- **EKS:** Kubernetes cluster with 3 node groups and auto-scaling
- **Aurora:** PostgreSQL Serverless v2 with automatic capacity scaling
- **DNS:** Route 53 and ACM certificate management
- **Observability:** CloudWatch logs, metrics, and Container Insights

### Deployment Patterns
- **SR-HA:** Production-ready pattern (v1.0)
- **SR-Simple:** Development pattern (v2.0 planned)

### Documentation
- 35 comprehensive documentation files
- Getting started guides
- Operational runbooks
- Cost estimation and capacity planning
- Troubleshooting guides

## 🔧 Requirements

- **Terraform:** >= 1.14.0
- **AWS CLI:** >= 2.0
- **kubectl:** >= 1.31
- **Helm:** >= 3.1
- **AWS Account:** With appropriate service quotas
- **Coder License:** Premium license required

See [Prerequisites](docs/getting-started/prerequisites.md) for complete requirements.

## 💰 Cost Estimation

| Pattern | Availability | Users | Monthly Cost |
|---------|--------------|-------|--------------|
| SR-HA | 99.9% (3 AZ) | 100-500 | $2,500-4,000 |
| SR-HA (24/7) | 99.9% (3 AZ) | 100-500 | $4,000-6,000 |
| SR-Simple | 95% (1 AZ) | <20 | $600-800 |

See [Cost Estimation Guide](docs/reference/cost-estimation.md) for detailed breakdowns.

## 🗺️ Roadmap

### v1.0 (Current) ✅
- [x] SR-HA pattern with time-based auto-scaling
- [x] Spot instance support for cost optimization
- [x] Aurora Serverless v2 database
- [x] Comprehensive documentation
- [x] Feature flag architecture

### v2.0 (Planned) 🚧
- [ ] SR-Simple pattern for dev/test
- [ ] Karpenter auto-scaling
- [ ] Terraform Registry publication

## 🤝 Contributing

Contributions welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

[License information to be added]

## 🆘 Getting Help

- **Documentation:** [docs/README.md](docs/README.md)
- **FAQ:** [docs/reference/faq.md](docs/reference/faq.md)
- **Issues:** [GitHub Issues](https://github.com/ausbru87/coder-aws-deploy/issues)
- **Coder Docs:** https://coder.com/docs

## 🏷️ Version

**Version:** 1.0.0
**Release Date:** 2025-01-16
**Coder Version:** 2.29.1 (ESR)
**Terraform Version:** >= 1.14.0
**AWS Provider:** ~> 6.26
**Kubernetes:** 1.34
**Aurora PostgreSQL:** 16.6

---

Built with ❤️ for the Coder community
