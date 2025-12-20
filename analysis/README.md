# Analysis Documents

This folder contains key analysis documents that show the **decision-making process and validation work** that led to the current deployment guide.

## Document Overview

### AWS_PREREQUISITES_CHECKLIST.md
**Source:** `coder-aws-deployment-analysis`

Comprehensive checklist validating AWS prerequisites before deployment:
- AWS account requirements and IAM permissions
- Service quotas and limits verification
- Tool and CLI installations
- Network planning (VPC, subnets, CIDR blocks)
- Domain and certificate requirements

This document represents the initial validation phase to ensure AWS readiness.

### DEPLOYMENT_ANALYSIS.md
**Source:** `coder-aws-deployment-analysis/ai-coder-analysis`

Deep analysis of the ai.coder.com production deployment:
- Complete infrastructure breakdown (~13,500 lines of Terraform)
- Multi-region architecture analysis (control plane + regional proxies)
- Module hierarchy and dependencies
- Cost estimation and capacity planning
- Lessons learned from production

This document analyzed the production ai.coder.com deployment to extract patterns and best practices.

### QUICKSTART.md
**Source:** `coder-aws-deployment-analysis/ai-coder-analysis`

Fast-track deployment guide (60-90 minutes) based on the production analysis:
- Streamlined single-region deployment
- Step-by-step Terraform execution
- Critical configuration decisions
- Verification steps

This represents the first attempt to create a simplified guide from the production architecture.

### decisions.md
**Source:** This repository

Technical decision log documenting authentication approach selection:
- Comparison of CSI Secrets Store + Pod Identity vs IRSA
- Testing results and failure modes
- Final recommendation: IRSA with managed EKS add-on
- Rationale for production deployment

This documents a critical architectural decision made during guide development.

## Project Progression

The analysis documents show this evolution:

1. **AWS_PREREQUISITES_CHECKLIST.md** → Validated infrastructure readiness
2. **DEPLOYMENT_ANALYSIS.md** → Analyzed production Terraform deployment
3. **QUICKSTART.md** → Extracted simplified deployment guide
4. **decisions.md** → Made specific technical choices for guide

This analysis work informed the current **deployment-guide/** structure, which simplifies the production architecture into step-by-step AWS CLI and eksctl commands for easier adoption.

## Key Insights

- **Production deployment**: 13,500 lines of Terraform across 90 files (ai.coder.com)
- **Target capacity**: 500 peak concurrent workspaces
- **Deployment approach evolved**: Terraform IaC → Simplified CLI-based guide
- **Critical decision**: IRSA over Pod Identity for secrets management
- **Time savings**: 60-90 minute deployment from blank AWS account
