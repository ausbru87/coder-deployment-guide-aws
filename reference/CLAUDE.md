# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a production-ready Terraform infrastructure-as-code solution for deploying Coder (cloud development environment platform) on Amazon EKS. It supports up to 3000 concurrent workspaces with 99.9% availability and implements AWS Well-Architected Framework principles.

**Key Features:**
- Multi-AZ EKS deployment with dedicated node groups (control plane, provisioners, workspaces)
- Aurora PostgreSQL Serverless v2 with automated backups and multi-AZ HA
- Two-layer template architecture for portable workspace definitions
- Comprehensive observability with CloudWatch integration
- Day 0/1/2 operational model using multiple Terraform providers

## Architecture

### Technology Stack
- **Infrastructure as Code**: Terraform 1.5+ (~88 .tf files)
- **Cloud Platform**: AWS (EKS, RDS Aurora, ElastiCache, VPC, Route 53, ACM, CloudWatch)
- **Container Orchestration**: Amazon EKS 1.31 with three dedicated node groups
- **Application Deployment**: Helm 3.0+, Kubernetes manifests
- **Terraform Providers**: AWS (~6.26), Kubernetes (~3.0), Helm (~3.1), coderd (~0.0.11)

### Directory Structure
```
terraform/
├── main.tf                      # Root module configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── backend.tf                   # S3 backend configuration
├── coderd.tf                    # Coderd provider (Day 1/2 operations)
├── coderd_variables.tf          # Coderd provider variables
├── backend-config/
│   └── prod.hcl                 # Production backend config
├── environments/
│   ├── prod.tfvars              # Production configuration
│   └── prod-example.tfvars      # Example configuration template
├── docs/                        # Operational documentation
│   ├── deployment-guide.md
│   ├── rbac-configuration.md
│   ├── provisioner-key-management.md
│   ├── service-account-token-management.md
│   ├── security-controls.md
│   ├── idp-configuration-guide.md
│   ├── scale-testing-guide.md
│   └── configuration-reference.md
├── test/                        # Go-based Terratest tests
│   ├── terraform_test.go        # Unit tests
│   ├── property_test.go         # Property-based tests
│   ├── scaletest/               # Scale testing utilities
│   └── README.md
├── examples/                    # Usage examples
│   ├── coderd-provider/
│   └── template-pairings/
└── modules/
    ├── vpc/                     # VPC, subnets, NAT, endpoints, security groups
    ├── eks/                     # EKS cluster, node groups, IAM, controllers
    ├── aurora/                  # Aurora PostgreSQL Serverless v2
    ├── dns/                     # Route 53 records, ACM certificates
    ├── observability/           # CloudWatch logs, metrics, dashboards, alarms
    ├── quota-validation/        # AWS quota pre-flight checks
    └── coder/                   # Coder Helm deployment and templates
        ├── main.tf              # Helm chart installation
        ├── coderd_provider.tf   # Day 1/2 operations (groups, templates)
        ├── templates.tf         # Template composition orchestration
        ├── templates/           # Monolithic templates (legacy)
        ├── template-architecture/   # Two-layer template system
        │   ├── contract/            # Contract schema definitions
        │   ├── validation/          # Contract validation
        │   ├── composition/         # Template composition logic
        │   ├── pairings/            # Default toolchain-base pairings
        │   ├── deployment/          # coderd_template deployment
        │   ├── ci-cd/               # CI/CD workflows and scripts
        │   ├── toolchains/          # Portable toolchain templates
        │   │   ├── swdev-toolchain/    # Software development
        │   │   ├── windev-toolchain/   # Windows development
        │   │   └── datasci-toolchain/  # Data science
        │   └── bases/               # Instance-specific infrastructure
        │       ├── base-k8s/           # Kubernetes pod workspaces
        │       ├── base-ec2-linux/     # Linux EC2 workspaces
        │       ├── base-ec2-windows/   # Windows EC2 with DCV/RDP
        │       └── base-ec2-gpu/       # GPU EC2 for ML workloads
        └── values/              # Helm values templates
```

### Module Hierarchy
The Terraform modules follow a clear hierarchy:
1. **Infrastructure modules**: `vpc`, `eks`, `aurora`, `dns`, `observability` - provision AWS resources
2. **Quota validation**: `quota-validation` - pre-flight checks for AWS service quotas
3. **Coder module**: `coder` - deploys Coder via Helm and manages Day 1/2 operations
4. **Template architecture**: Two-layer system separating portable toolchains from infrastructure

### Two-Layer Template Architecture
The template system separates workspace definitions into two layers:

**Layer 1: Toolchain Templates (Portable)**
- Located in `modules/coder/template-architecture/toolchains/`
- Declare WHAT a workspace should be (languages, tools, capabilities)
- Examples: `swdev-toolchain`, `windev-toolchain`, `datasci-toolchain`
- Portable across Coder instances

**Layer 2: Infrastructure Base Modules (Instance-Specific)**
- Located in `modules/coder/template-architecture/bases/`
- Define HOW workspaces run (compute, networking, storage, identity)
- Examples: `base-k8s`, `base-ec2-linux`, `base-ec2-windows`, `base-ec2-gpu`
- Instance-specific configuration

**Composition:**
- `composition/` module combines toolchains with bases
- `pairings/` defines default combinations (e.g., `swdev-toolchain` + `base-k8s` = `pod-swdev`)
- `validation/` enforces contract compliance and security policies
- `deployment/` uses `coderd_template` resource for declarative management

## Common Commands

### Terraform Operations

```bash
# Navigate to terraform directory
cd terraform

# Initialize with local backend (first time)
terraform init

# Initialize with S3 backend (after bootstrap)
terraform init -backend-config=backend-config/prod.hcl -migrate-state

# Format code (always run before commits)
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan changes
terraform plan -var-file=environments/prod.tfvars -out=tfplan

# Apply infrastructure (Day 0)
terraform apply tfplan

# Apply with coderd provider enabled (Day 1/2)
export CODER_SESSION_TOKEN="your-admin-token"
terraform apply -var-file=environments/prod.tfvars -var="enable_coderd_provider=true"

# Target specific module
terraform apply -var-file=environments/prod.tfvars -target=module.coder

# Destroy infrastructure (use with caution)
terraform destroy -var-file=environments/prod.tfvars

# View outputs
terraform output
terraform output -raw coder_access_url
```

### Testing

```bash
# Navigate to test directory
cd terraform/test

# Install Go dependencies
go mod tidy

# Run all tests
go test -v ./...

# Run specific test
go test -v -run TestProperty_HTTPSEnforcement

# Run with coverage
go test -v -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Run scale tests
cd scaletest
export CODER_URL=https://coder.example.com
export CODER_SESSION_TOKEN=your-api-token
./run-scaletest.sh --test all
```

### Module Development

```bash
# Validate a specific module
cd modules/eks
terraform init
terraform validate

# Test module in isolation
cd modules/vpc
terraform plan

# Format module files
terraform fmt -recursive modules/
```

### AWS Operations

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --region us-east-1 --name coder-prod

# Check node group status
aws eks describe-nodegroup --cluster-name coder-prod --nodegroup-name coder-prod-ws

# Scale node group
aws eks update-nodegroup-config \
  --cluster-name coder-prod \
  --nodegroup-name coder-prod-ws \
  --scaling-config minSize=20,maxSize=300,desiredSize=50

# Check Aurora cluster status
aws rds describe-db-clusters --db-cluster-identifier coder-prod

# Run quota pre-flight check
./modules/quota-validation/scripts/preflight-check.sh
```

### Kubernetes Operations

```bash
# Check Coder pods
kubectl get pods -n coder

# Check provisioner pods
kubectl get pods -n coder-prov

# View Coder logs
kubectl logs -n coder -l app.kubernetes.io/name=coder -f

# View provisioner logs
kubectl logs -n coder-prov -l app.kubernetes.io/name=coder-provisioner -f

# Scale provisioner deployment
kubectl scale deployment coder-provisioner-default -n coder-prov --replicas=10

# Get deployed image versions
kubectl get pods -n coder -o jsonpath='{.items[*].spec.containers[*].image}'
```

## Day 0/1/2 Operations Model

This deployment uses a phased operational model:

**Day 0: Infrastructure Provisioning**
- Uses Terraform AWS provider to provision VPC, EKS, Aurora, DNS, observability
- Run with `enable_coderd_provider = false` (default)
- Command: `terraform apply -var-file=environments/prod.tfvars`

**Day 1: Initial Configuration**
- Uses coderd Terraform provider to configure Coder after infrastructure is deployed
- Set up OIDC authentication, deploy initial templates, create IDP groups
- Requires `CODER_SESSION_TOKEN` environment variable
- Command: `terraform apply -var-file=environments/prod.tfvars -var="enable_coderd_provider=true"`

**Day 2: Ongoing Management**
- Uses coderd provider for template updates, group management, quota changes
- Rotate provisioner keys (90-day cycle)
- Command: `terraform apply -var-file=environments/prod.tfvars` (with coderd provider enabled)

## Key Configuration Files

### Environment Configuration
- `environments/prod.tfvars` - Production variables (region, domain, scaling config)
- `environments/prod-example.tfvars` - Template with all available variables
- `backend-config/prod.hcl` - S3 backend configuration

### Required Variables
Must be set in tfvars or environment:
- `base_domain` - Your domain (e.g., example.com)
- `oidc_issuer_url` - Identity provider URL
- `oidc_client_id` - OIDC client ID
- `oidc_client_secret_arn` - Secrets Manager ARN for OIDC secret
- `owner` - Resource owner for tagging

### Important Defaults
- `aws_region` = `us-east-1`
- `eks_cluster_version` = `1.31`
- `max_workspaces` = `3000`
- `coderd_replicas` = `2` (static, no auto-scaling)
- `ws_use_spot_instances` = `true`
- `aurora_backup_retention_days` = `90` (minimum for compliance)

## Template Contract System

When working with the template architecture, understand the contract interface:

**Contract Inputs** (Infrastructure Base Accepts):
- `workspace_name` - Workspace identifier
- `owner` - Workspace owner username
- `compute_profile` - CPU, memory, storage, GPU configuration
- `image_id` - Toolchain container image reference
- `capabilities` - Requested capabilities object

**Contract Outputs** (Infrastructure Base Provides):
- `agent_endpoint` - Coder agent connection endpoint
- `runtime_env` - Environment variables map
- `volume_mounts` - Volume mount configuration
- `metadata` - Provenance and tracking data

**Standard Capabilities**:
- `persistent-home` (boolean, default: true) - Persist /home/coder
- `network-egress` (enum: none/https-only/unrestricted, default: https-only)
- `identity-mode` (enum: oidc/iam/workload-identity, default: iam)
- `gpu-support` (boolean, default: false)
- `gui-vnc` (boolean, default: false) - VNC desktop for Linux
- `gui-rdp` (boolean, default: false) - RDP desktop for Windows

## Troubleshooting

### Common Issues

**Pods Stuck in Pending:**
```bash
kubectl get pods -A --field-selector=status.phase=Pending
kubectl describe nodes | grep -A5 "Taints:"
aws eks describe-nodegroup --cluster-name coder-prod --nodegroup-name coder-prod-ws
```
Solution: Verify node group capacity, check node taints match pod tolerations

**Database Connection Errors:**
```bash
aws rds describe-db-clusters --db-cluster-identifier coder-prod
aws secretsmanager get-secret-value --secret-id coder/prod/db-password
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i database
```
Solution: Verify security group allows port 5432, check IAM role permissions

**OIDC Authentication Failures:**
```bash
kubectl get configmap -n coder coder-config -o yaml
kubectl logs -n coder -l app.kubernetes.io/name=coder | grep -i oidc
```
Solution: Verify issuer URL, client ID, and client secret in Secrets Manager

**Template Composition Errors:**
```bash
cd modules/coder/template-architecture/validation
terraform plan
```
Solution: Verify toolchain capabilities match base module support

### Log Locations
- Coder (coderd): CloudWatch `/coder/prod/coderd`
- Provisioners: CloudWatch `/coder/prod/provisioner`
- Workspaces: CloudWatch `/coder/prod/workspaces`
- EKS Control Plane: CloudWatch `/aws/eks/coder-prod/cluster`
- VPC Flow Logs: CloudWatch `/coder/prod/vpc-flow-logs`

## Coding Standards

### Terraform Style
- Always run `terraform fmt -recursive` before committing
- Use snake_case for module directories and files
- Use lowerCamelCase for variable names
- Group tfvars sections: inputs → networking → security → observability
- Include descriptive comments for complex logic
- Use data sources over hardcoded values

### Module Structure
Each module should have:
- `main.tf` - Primary resource definitions
- `variables.tf` - Input variables with descriptions and types
- `outputs.tf` - Output values
- `versions.tf` - Terraform and provider version constraints
- `README.md` - Module documentation

### Testing Requirements
- Unit tests: Validate Terraform syntax and configuration
- Property tests: Validate requirements from design document
- Include property annotation comments in test functions
- Run tests before submitting changes

### Commit Conventions
Follow Conventional Commits format:
- `feat(module-name): description` - New features
- `fix(module-name): description` - Bug fixes
- `docs: description` - Documentation changes
- `test: description` - Test additions/updates
- `chore: description` - Maintenance tasks

For infrastructure changes, include `terraform plan` output in PR description.

## Security Considerations

**Secrets Management:**
- Never commit credentials, API tokens, or Terraform state
- Use AWS Secrets Manager for sensitive values (reference via ARN)
- Use IAM roles and IRSA instead of static credentials
- Store OIDC client secrets in Secrets Manager

**State Management:**
- Configure S3 backend with encryption enabled
- Use DynamoDB for state locking
- Store backend config in `backend-config/prod.hcl` (not in version control if contains sensitive values)
- Use separate state files per environment

**Network Security:**
- Resources deploy in private subnets with NAT gateway egress
- Security groups follow least privilege principle
- Network ACLs provide defense in depth
- VPC endpoints reduce internet exposure for AWS services

**Template Security:**
- Override policies enforce restrictions on network, identity, and privileges
- Capability system prevents direct infrastructure access from toolchains
- Validation module checks contract compliance before composition

## Performance and Scaling

### Capacity Planning
| Users | Provisioner Nodes | Workspace Nodes | Provisioner Replicas |
|-------|------------------|-----------------|---------------------|
| <10   | 0-2              | 10-20           | 6 (default)         |
| 10-30 | 2-5              | 20-50           | 8-10                |
| 30-100| 5-10             | 50-100          | 10-15               |
| 100+  | 10-20            | 100-200         | 15-20               |

### Time-Based Scaling
Node groups scale based on work hours (default: 0645-1815 ET):
- Configure via `scaling_schedule_start` and `scaling_schedule_stop` variables
- Adjust timezone via `scaling_timezone` variable
- Scales up 15 minutes before work hours, down 15 minutes after

### Manual Scaling
Use AWS CLI or Terraform to adjust node group sizes. For Terraform, update tfvars:
```hcl
ws_node_max_size = 300
ws_node_desired_peak = 100
prov_node_max_size = 30
prov_node_desired_peak = 15
```

## Important Documentation

**Operational Guides** (in `terraform/docs/`):
- `deployment-guide.md` - Step-by-step deployment procedures
- `rbac-configuration.md` - Role-based access control setup
- `provisioner-key-management.md` - Key rotation procedures (90-day cycle)
- `service-account-token-management.md` - Token lifecycle management
- `security-controls.md` - Security implementation details
- `idp-configuration-guide.md` - Identity provider integration
- `scale-testing-guide.md` - Performance validation procedures
- `configuration-reference.md` - Complete variable reference

**Template Architecture** (in `modules/coder/template-architecture/`):
- Main `README.md` - Architecture overview
- `contract/README.md` - Contract specification
- `validation/README.md` - Validation logic
- `composition/README.md` - Template composition
- `ci-cd/README.md` - CI/CD workflows for template governance

## Known Limitations

- Coderd replicas are statically configured (no HPA)
- Provisioner scaling is manual (no auto-scaling based on queue depth)
- Cross-region backup configuration requires manual DR planning
- Workspace node group uses Cluster Autoscaler (not Karpenter)
- Template governance CI/CD requires external workflow integration
