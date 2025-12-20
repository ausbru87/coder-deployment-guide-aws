# Coder AWS Deployment Reference Architecture

This repository contains a comprehensive, production-ready reference architecture for deploying [Coder](https://coder.com) on AWS with integrated AI capabilities.

## What's Inside

The **ai.coder.com** submodule (from [coder/ai.coder.com](https://github.com/coder/ai.coder.com)) provides:
- **~13,500 lines of Terraform** across 90 files for complete Infrastructure as Code
- **Multi-region deployment** (us-east-2, us-west-2, eu-west-2) with hub-and-spoke architecture
- **AI integration** via LiteLLM (AWS Bedrock + GCP Vertex AI)
- **45 reusable Terraform modules** for networking, security, Kubernetes, and Coder
- **Production-proven** infrastructure supporting 10-30+ concurrent users

## Quick Links

- **[QUICKSTART.md](./ai-coder-analysis/QUICKSTART.md)** - Fast-track deployment guide (60-90 minutes)
- **[DEPLOYMENT_ANALYSIS.md](./ai-coder-analysis/DEPLOYMENT_ANALYSIS.md)** - Complete analysis and detailed deployment guide
- **[ai.coder.com/README.md](./ai.coder.com/README.md)** - Submodule documentation
- **[ai.coder.com/docs/workshops/ARCHITECTURE.md](./ai.coder.com/docs/workshops/ARCHITECTURE.md)** - System architecture overview

## Can This Deploy to a Blank AWS Account?

**YES!** This repository can deploy a complete Coder environment from scratch on a blank AWS account.

**What gets deployed:**
- ✅ Amazon EKS clusters with auto-scaling (Karpenter)
- ✅ Amazon RDS PostgreSQL database
- ✅ Amazon ElastiCache Redis
- ✅ Amazon ECR private registry
- ✅ VPC, subnets, NAT gateways, load balancers
- ✅ Coder Server, proxies, and provisioners
- ✅ LiteLLM for AI model routing
- ✅ All supporting Kubernetes services

**Prerequisites required:**
- AWS account with appropriate permissions
- S3 bucket for Terraform state
- GitHub OAuth app for authentication
- Domain name with DNS access
- Let's Encrypt email for SSL

**Estimated deployment time:** 60-90 minutes (single region)

**Estimated monthly cost:** $800-1,200 (for <10 concurrent users)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         CloudFlare DNS                          │
│              (coder.domain.com, *.coder.domain.com)             │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
┌───────▼────────┐              ┌────────▼─────────┐
│   us-east-2    │              │   us-west-2      │
│ (Control Plane)│              │  (Proxy Cluster) │
├────────────────┤              ├──────────────────┤
│ • Coder Server │              │ • Coder Proxy    │
│ • Provisioners │              │ • Provisioners   │
│ • LiteLLM      │              │ • Workers        │
│ • RDS Postgres │              │ • Karpenter      │
│ • Redis Cache  │              └──────────────────┘
│ • ECR Registry │
│ • Karpenter    │              ┌──────────────────┐
└────────────────┘              │   eu-west-2      │
                                │  (Proxy Cluster) │
                                ├──────────────────┤
                                │ • Coder Proxy    │
                                │ • Provisioners   │
                                │ • Workers        │
                                │ • Karpenter      │
                                └──────────────────┘
```

## Getting Started

### Option 1: Quick Start (Recommended)

Follow the **[QUICKSTART.md](./ai-coder-analysis/QUICKSTART.md)** guide for a streamlined deployment process.

### Option 2: Detailed Analysis

Read the **[DEPLOYMENT_ANALYSIS.md](./ai-coder-analysis/DEPLOYMENT_ANALYSIS.md)** for:
- Complete architecture analysis
- Detailed prerequisites
- Step-by-step deployment instructions
- Known limitations and mitigations
- Operational considerations

## Repository Structure

```
coder-aws-deployment/
├── README.md                    # This file
├── ai-coder-analysis/           # Analysis and deployment documentation
│   ├── QUICKSTART.md            # Fast-track deployment guide
│   └── DEPLOYMENT_ANALYSIS.md   # Complete analysis and detailed guide
└── ai.coder.com/                # Submodule with Terraform code
    ├── infra/aws/               # Infrastructure by region
    │   ├── us-east-2/           # Control plane
    │   ├── us-west-2/           # Oregon proxy
    │   └── eu-west-2/           # London proxy
    ├── modules/                 # Reusable Terraform modules
    │   ├── network/             # VPC, subnets, NAT
    │   ├── security/            # IAM roles and policies
    │   ├── k8s/                 # Kubernetes apps
    │   └── coder/               # Coder resources
    ├── images/                  # Docker workspace images
    ├── coder/                   # Coder templates and config
    └── docs/                    # Operational documentation
```

## Key Features

- **Multi-Region:** Hub-and-spoke architecture for global distribution
- **Auto-Scaling:** Karpenter for dynamic node provisioning
- **High Availability:** Replicated control plane components
- **AI-Ready:** Pre-configured LiteLLM with AWS Bedrock and GCP Vertex AI
- **Cost-Optimized:** Uses fck-nat for NAT gateway cost savings
- **Production-Proven:** Battle-tested with 10-30+ concurrent users
- **Fully Automated:** Infrastructure as Code with Terraform
- **Modular Design:** 45 reusable modules for customization

## What You'll Deploy

**Infrastructure:**
- Amazon EKS (Kubernetes) clusters
- Amazon RDS PostgreSQL (Coder database)
- Amazon ElastiCache Redis (LiteLLM caching)
- Amazon ECR (Private container registry)
- VPC with public/private subnets
- NAT gateways and Internet gateways
- Network Load Balancers

**Applications:**
- Coder Server (control plane)
- Coder Workspace Provisioners
- LiteLLM (AI model router)
- cert-manager (SSL certificates)
- AWS Load Balancer Controller
- AWS EBS CSI Driver
- Karpenter (node auto-scaling)
- Kubernetes Metrics Server

**AI Capabilities:**
- Claude AI models via AWS Bedrock
- Optional: Claude via GCP Vertex AI
- Custom workspace images for Claude Code CLI
- Custom workspace images for Goose AI

## Support & Documentation

- **Issues:** Open an issue in this repository
- **Coder Docs:** https://coder.com/docs
- **Submodule Docs:** See `ai.coder.com/README.md`
- **Runbooks:** See `ai.coder.com/docs/workshops/`

## License

See the ai.coder.com submodule for license information.

---

**Last Updated:** November 16, 2025
**Branch:** ai-coder-deployment-analysis
