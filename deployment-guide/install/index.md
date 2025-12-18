# Installation Overview

This section covers deploying Coder on AWS EKS.

## Steps

| Step | Document | Description | Time |
|------|----------|-------------|------|
| 1 | [Infrastructure](infrastructure.md) | VPC, EKS, RDS, ACM | ~30 min |
| 2 | [Coder](coder.md) | Helm install, DNS, verification | ~10 min |

## Prerequisites

Before starting, complete the [prerequisites](../prerequisites/index.md):

- [ ] AWS CLI configured
- [ ] kubectl, Helm, eksctl installed
- [ ] IAM permissions verified
- [ ] EC2 vCPU quota ≥3,000
- [ ] Route 53 hosted zone ready
- [ ] OIDC provider configured

## Architecture

See [Reference Architecture](../architecture/diagrams.md) for the target deployment.
