# Installation Overview

This section covers deploying Coder on AWS EKS.

## Scope

This guide is opinionated for:

- **500 peak concurrent workspaces** with 99.9% availability target
- **Kubernetes (pod-based) workspaces only** — EC2/VM workspaces require additional IAM configuration not covered here
- **High availability** — multi-replica coderd, RDS Multi-AZ, pod anti-affinity
- **External provisioners** — dedicated node group for provisioner workloads
- **Single AWS region** deployment (no multi-region)
- **Public-facing** Coder instance (internet-accessible via NLB)
- **RDS PostgreSQL Multi-AZ** for database (not Aurora, not self-managed)
- **ACM + NLB** for TLS termination (no cert-manager)
- **Pod Identity** for IAM authentication (not IRSA)
- **Observability stack** — Prometheus, Grafana, alerting

### Not Covered

- Air-gapped / private deployments
- Multi-region deployments
- Custom identity providers (OIDC setup referenced but not detailed)

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
