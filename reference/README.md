# Reference Architectures

This folder contains reference architectures and production patterns that informed the current deployment guide.

## Document Overview

### REFERENCE_ARCHITECTURE.md
**Source:** `coder-aws-deployment` (main README)

Reference to the ai.coder.com production deployment:
- Multi-region hub-and-spoke architecture
- 45 reusable Terraform modules
- Integrated AI capabilities (LiteLLM + AWS Bedrock)
- Production-proven for 10-30+ concurrent users
- Complete IaC with ~13,500 lines of Terraform

This is the **gold standard production deployment** that serves as the foundation for all other guides.

### TERRAFORM_PATTERNS.md
**Source:** `aws-arch-SR-v1` (main README)

Single-region Terraform patterns for Coder on AWS:
- **SR-HA**: High availability pattern (3 AZs, multi-node, auto-scaling)
- **SR-Simple**: Development/test pattern (single AZ, minimal resources)
- Pattern-based deployment approach with `.tfvars` files
- Cost optimization strategies (spot instances, time-based scaling)
- Production-ready modules and documented patterns

This represents an alternative Terraform-based approach optimized for single-region deployments.

### ARCHITECTURE_OVERVIEW.md
**Source:** `aws-arch-SR-v1/docs/getting-started/overview.md`

Detailed architectural overview of the Terraform patterns:
- Component architecture (control plane, provisioners, workspaces)
- Network topology and security groups
- High availability design decisions
- Module structure and organization
- Deployment patterns comparison

Provides architectural context for the Terraform implementation.

### CLAUDE.md
**Source:** `aws-arch-SR-v1`

AI assistant guidance for the Terraform patterns repository:
- Module hierarchy and relationships
- Common operations and commands
- Coding standards and conventions
- Testing and validation approaches

Shows how the Terraform patterns were structured for maintainability.

### CONTRIBUTING.md
**Source:** `aws-arch-SR-v1`

Contribution guidelines for the Terraform patterns:
- Development workflow
- Module development standards
- Documentation requirements
- Testing expectations

Demonstrates production-grade infrastructure standards.

## Architecture Evolution

The reference architectures show this progression:

1. **Production multi-region** (ai.coder.com) → Full-featured Terraform with hub-and-spoke, AI integration
2. **Single-region patterns** (aws-arch-SR-v1) → Simplified Terraform modules with HA and simple variants
3. **Deployment guide** (this repo) → CLI-based guide without Terraform for accessibility

## Key Differences

| Aspect | Production (ai.coder.com) | Terraform Patterns | This Guide |
|--------|--------------------------|-------------------|------------|
| **IaC Tool** | Terraform (~13.5k lines) | Terraform (modular) | AWS CLI + eksctl |
| **Regions** | Multi-region (3) | Single-region | Single-region |
| **Target Users** | 10-30+ concurrent | 100-500 concurrent | 500 peak concurrent |
| **Complexity** | High (production) | Medium (patterns) | Low (step-by-step) |
| **AI Integration** | Yes (LiteLLM) | No | No |
| **Deployment Time** | 60-90 min | 60-90 min | Similar |
| **Prerequisites** | High IaC knowledge | Terraform experience | AWS CLI basics |

## When to Use Each

- **Production Reference (ai.coder.com)**: Multi-region deployments, AI integration, production scale
- **Terraform Patterns (aws-arch-SR-v1)**: IaC-managed infrastructure, repeatable deployments, CI/CD integration
- **This Deployment Guide**: Quick starts, learning Coder, single-region deployments, minimal IaC knowledge

All three approaches produce production-ready Coder deployments on AWS with different trade-offs.
