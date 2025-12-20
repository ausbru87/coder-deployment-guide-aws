# Architecture Overview

This document provides architectural diagrams and explanations for the Coder platform deployment on AWS EKS. The solution supports up to 3000 concurrent workspaces with 99.9% availability, following AWS Well-Architected Framework principles for reliability, security, and cost optimization.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Network Architecture](#network-architecture)
3. [Security Architecture](#security-architecture)
4. [EKS Cluster Architecture](#eks-cluster-architecture)
5. [Data Flow Architecture](#data-flow-architecture)
6. [DR/HA Architecture](#drha-architecture)
7. [Template Architecture](#template-architecture)

## High-Level Architecture

The Coder platform is deployed across multiple AWS services following the AWS Well-Architected Framework principles for reliability, security, and cost optimization.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Region (us-east-1)                                  │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                              VPC (10.0.0.0/16)                               │    │
│  │                                                                              │    │
│  │   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                    │    │
│  │   │ Public AZ-a  │   │ Public AZ-b  │   │ Public AZ-c  │                    │    │
│  │   │  [NAT GW]    │   │  [NAT GW]    │   │  [NAT GW]    │                    │    │
│  │   │  [NLB ENI]   │   │  [NLB ENI]   │   │  [NLB ENI]   │                    │    │
│  │   └──────────────┘   └──────────────┘   └──────────────┘                    │    │
│  │                                                                              │    │
│  │   ┌──────────────────────────────────────────────────────────────────────┐  │    │
│  │   │                        EKS Cluster                                    │  │    │
│  │   │  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐            │  │    │
│  │   │  │ coder-control  │ │  coder-prov    │ │   coder-ws     │            │  │    │
│  │   │  │   (coderd)     │ │ (provisioners) │ │  (workspaces)  │            │  │    │
│  │   │  │  m5.large x2-3 │ │ c5.2xl x0-20   │ │ m5.2xl x10-200 │            │  │    │
│  │   │  └────────────────┘ └────────────────┘ └────────────────┘            │  │    │
│  │   └──────────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                              │    │
│  │   ┌──────────────────────────────────────────────────────────────────────┐  │    │
│  │   │                    Aurora PostgreSQL Serverless v2                    │  │    │
│  │   │              [Writer AZ-a]  [Reader AZ-b]  [Reader AZ-c]              │  │    │
│  │   └──────────────────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │
│  │  Route 53  │  │    ACM     │  │ CloudWatch │  │  Secrets   │  │    S3      │    │
│  │   (DNS)    │  │  (Certs)   │  │  (Logs)    │  │  Manager   │  │  (State)   │    │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘  └────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | AWS Service | Purpose |
|-----------|-------------|---------|
| Networking | VPC, Subnets, NAT GW | Network isolation and segmentation |
| Compute | EKS, EC2 | Kubernetes cluster and workspace nodes |
| Database | Aurora PostgreSQL Serverless v2 | Coder metadata storage with multi-AZ HA |
| Load Balancing | Network Load Balancer | TLS termination, traffic distribution |
| DNS | Route 53 | Domain management for ACCESS_URL |
| Certificates | ACM | TLS certificate management with auto-renewal |
| Secrets | Secrets Manager | Credential and API token storage |
| Monitoring | CloudWatch, AMP (optional) | Metrics, logs, alerts |
| Storage | EBS via CSI | Workspace persistent volumes |

## Network Architecture

The VPC is designed with dedicated subnets for each component type, enabling network isolation and independent scaling.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              VPC: 10.0.0.0/16                                        │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         Public Subnets (NAT/NLB)                             │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │  10.0.0.0/20    │  │  10.0.16.0/20   │  │  10.0.32.0/20   │              │    │
│  │  │     AZ-a        │  │     AZ-b        │  │     AZ-c        │              │    │
│  │  │  NAT GW + NLB   │  │  NAT GW + NLB   │  │  NAT GW + NLB   │              │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                    Private Subnets - Control Plane                           │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │  10.0.48.0/20   │  │  10.0.64.0/20   │  │  10.0.80.0/20   │              │    │
│  │  │     AZ-a        │  │     AZ-b        │  │     AZ-c        │              │    │
│  │  │  coderd nodes   │  │  coderd nodes   │  │  coderd nodes   │              │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                    Private Subnets - Provisioners                            │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │  10.0.96.0/20   │  │  10.0.112.0/20  │  │  10.0.128.0/20  │              │    │
│  │  │     AZ-a        │  │     AZ-b        │  │     AZ-c        │              │    │
│  │  │ provisioner nds │  │ provisioner nds │  │ provisioner nds │              │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                    Private Subnets - Workspaces (Large)                      │    │
│  │  ┌───────────────────────────────────────────────────────────────────────┐  │    │
│  │  │                        10.0.144.0/18                                   │  │    │
│  │  │              Workspace nodes across all AZs (up to 3000)               │  │    │
│  │  └───────────────────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                    Database Subnets (Aurora)                                 │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │  10.0.208.0/21  │  │  10.0.216.0/21  │  │  10.0.224.0/21  │              │    │
│  │  │     AZ-a        │  │     AZ-b        │  │     AZ-c        │              │    │
│  │  │  Aurora Writer  │  │  Aurora Reader  │  │  Aurora Reader  │              │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  VPC Endpoints: S3, ECR, Secrets Manager, CloudWatch, EKS API                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Subnet Allocation

| Subnet Type | CIDR Range | Purpose | IPs Available |
|-------------|------------|---------|---------------|
| Public | 10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20 | NAT Gateways, NLB ENIs | ~12,000 |
| Private (Control) | 10.0.48.0/20, 10.0.64.0/20, 10.0.80.0/20 | coderd nodes | ~12,000 |
| Private (Provisioner) | 10.0.96.0/20, 10.0.112.0/20, 10.0.128.0/20 | Provisioner nodes | ~12,000 |
| Private (Workspace) | 10.0.144.0/18 | Workspace nodes | ~16,000 |
| Database | 10.0.208.0/21, 10.0.216.0/21, 10.0.224.0/21 | Aurora PostgreSQL | ~6,000 |

### Design Rationale - Subnet Separation

- **Network Isolation**: Distinct security group rules and NACLs per component
- **Independent Scaling**: Each node group scales within its own CIDR allocation
- **Traffic Visibility**: VPC Flow Logs analyzed per subnet for security auditing
- **Blast Radius Containment**: Limits lateral movement if a workspace is compromised

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           Security Boundaries                                        │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                            IAM / IRSA                                        │    │
│  │                                                                              │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │ CoderServerRole │  │ CoderProvRole   │  │ AWSControllers  │              │    │
│  │  │                 │  │                 │  │ Roles           │              │    │
│  │  │ - Secrets Mgr   │  │ - EC2           │  │ - ALB Controller│              │    │
│  │  │ - RDS           │  │ - EKS           │  │ - EBS CSI       │              │    │
│  │  │                 │  │ - IAM PassRole  │  │                 │              │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                          Security Groups                                     │    │
│  │                                                                              │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │    Node SG      │  │     RDS SG      │  │  VPC Endpoint   │              │    │
│  │  │                 │  │                 │  │       SG        │              │    │
│  │  │ - NLB ingress   │  │ - 5432 from     │  │ - 443 from      │              │    │
│  │  │ - Inter-node    │  │   Node SG       │  │   Node SG       │              │    │
│  │  │ - Egress all    │  │                 │  │                 │              │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                            Encryption                                        │    │
│  │                                                                              │    │
│  │  - TLS 1.2+ at NLB (ACM certificates, auto-renewal)                         │    │
│  │  - AES-256 encryption at rest (Aurora, EBS)                                 │    │
│  │  - AES-128/256-GCM with ECDHE cipher suites                                 │    │
│  │  - Secrets Manager for credential storage                                    │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Security Controls

| Control | Implementation | Requirement |
|---------|----------------|-------------|
| TLS Termination | NLB with ACM certificates | 12.7, 12.8 |
| TLS Version | TLS 1.2 minimum, TLS 1.3 preferred | 12.8 |
| Cipher Suites | AES-128/256-GCM with ECDHE | 12.8a |
| Data at Rest | AES-256 encryption (Aurora, EBS) | 12.9 |
| IAM | IRSA for least-privilege pod access | 2.5 |
| Network | Private subnets, VPC endpoints | 3.1 |
| Secrets | AWS Secrets Manager integration | 3.4 |
| Audit | CloudTrail, VPC Flow Logs | 3.5 |

## EKS Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              EKS Cluster                                             │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                      Control Plane (AWS Managed)                             │    │
│  │                    Multi-AZ, Encrypted, OIDC Provider                        │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐            │
│  │    Node Group:     │  │    Node Group:     │  │    Node Group:     │            │
│  │   coder-control    │  │    coder-prov      │  │     coder-ws       │            │
│  │                    │  │                    │  │                    │            │
│  │  Instance: m5.large│  │  Instance: c5.2xl  │  │  Instance: m5.2xl  │            │
│  │  Min: 2            │  │  Min: 0            │  │  Min: 10           │            │
│  │  Max: 3            │  │  Max: 20           │  │  Max: 200          │            │
│  │  Scaling: Static   │  │  Scaling: Time     │  │  Scaling: Time     │            │
│  │                    │  │                    │  │  + Spot instances  │            │
│  │  Taints:           │  │  Taints:           │  │  Taints:           │            │
│  │  coder-control     │  │  coder-prov        │  │  coder-ws          │            │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘            │
│                                                                                      │
│  Namespaces:                                                                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐                    │
│  │   coder    │  │ coder-prov │  │  coder-ws  │  │ kube-system│                    │
│  │  (coderd)  │  │(provisioner│  │(workspaces)│  │(controllers│                    │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘                    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Node Group Configuration

| Node Group | Instance | Min | Max | Scaling | Purpose |
|------------|----------|-----|-----|---------|---------|
| coder-control | m5.large | 2 | 3 | Static | coderd, observability |
| coder-prov | c5.2xlarge | 0 | 20 | Time-based (0645-1815 ET) | External provisioners |
| coder-ws | m5.2xlarge | 10 | 200 | Time-based + Spot | Pod workspaces |

### Scaling Schedule

- Scale-up: 06:45 ET (completes 15 min before 07:00 work start)
- Scale-down: 18:15 ET (after 18:00 work end)
- Workspace nodes use spot instances with on-demand fallback

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              User Request Flow                                       │
│                                                                                      │
│  ┌──────────┐                                                                        │
│  │  User    │                                                                        │
│  │ (Browser/│                                                                        │
│  │   IDE)   │                                                                        │
│  └────┬─────┘                                                                        │
│       │ HTTPS (443)                                                                  │
│       ▼                                                                              │
│  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐                   │
│  │  Route   │────▶│   NLB    │────▶│  coderd  │────▶│  Aurora  │                   │
│  │    53    │     │ (TLS 1.2+│     │  (API)   │     │   (DB)   │                   │
│  └──────────┘     └──────────┘     └────┬─────┘     └──────────┘                   │
│                                         │                                           │
│                                         │ Workspace                                 │
│                                         │ Provisioning                              │
│                                         ▼                                           │
│                                    ┌──────────┐                                     │
│                                    │Provisioner│                                    │
│                                    │  (gRPC)   │                                    │
│                                    └────┬─────┘                                     │
│                                         │                                           │
│                    ┌────────────────────┼────────────────────┐                      │
│                    │                    │                    │                      │
│                    ▼                    ▼                    ▼                      │
│               ┌──────────┐        ┌──────────┐        ┌──────────┐                 │
│               │ Pod WS   │        │ EC2 Linux│        │EC2 Windows│                │
│               │(K8s Pod) │        │    WS    │        │    WS     │                │
│               └──────────┘        └──────────┘        └──────────┘                 │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘

Workspace Connectivity:

1. Pod Workspace → coderd (internal):
   [Pod WS] → K8s Service → [coderd pods]

2. EC2 Workspace → coderd (external path):
   [EC2 WS] → NAT GW → Internet → NLB → [coderd pods]

3. External Client → Workspace (via DERP relay):
   [Client] → NLB → [coderd/DERP] ← K8s Service ← [Pod WS]
   [Client] → NLB → [coderd/DERP] ← NLB ← NAT GW ← [EC2 WS]

4. External Client → Workspace (direct P2P after STUN):
   [Client] ←──── P2P (UDP) ────→ [Workspace]
```

## DR/HA Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         High Availability Design                                     │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         Multi-AZ Deployment                                  │    │
│  │                                                                              │    │
│  │     AZ-a                    AZ-b                    AZ-c                     │    │
│  │  ┌─────────┐             ┌─────────┐             ┌─────────┐                │    │
│  │  │ coderd  │             │ coderd  │             │ (spare) │                │    │
│  │  │ replica │             │ replica │             │         │                │    │
│  │  └─────────┘             └─────────┘             └─────────┘                │    │
│  │  ┌─────────┐             ┌─────────┐             ┌─────────┐                │    │
│  │  │ Aurora  │◄───────────▶│ Aurora  │◄───────────▶│ Aurora  │                │    │
│  │  │ Writer  │  Sync Repl  │ Reader  │  Sync Repl  │ Reader  │                │    │
│  │  └─────────┘             └─────────┘             └─────────┘                │    │
│  │  ┌─────────┐             ┌─────────┐             ┌─────────┐                │    │
│  │  │ NAT GW  │             │ NAT GW  │             │ NAT GW  │                │    │
│  │  └─────────┘             └─────────┘             └─────────┘                │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  Recovery Objectives:                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  RTO: 2 hours maximum                                                        │    │
│  │  RPO: 15 minutes maximum                                                     │    │
│  │  Availability Target: 99.9% (three nines)                                    │    │
│  │  Planned Maintenance: 90 min window (zero downtime preferred)                │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  Backup Strategy:                                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  - Aurora automated backups with point-in-time recovery                      │    │
│  │  - 90-day backup retention                                                   │    │
│  │  - Cross-region snapshot replication                                         │    │
│  │  - Monthly backup restore testing                                            │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  Failover Scenarios:                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  - Single AZ failure: Service continues via remaining AZs                    │    │
│  │  - Aurora failover: Automatic promotion of reader to writer                  │    │
│  │  - Node failure: Kubernetes reschedules pods to healthy nodes                │    │
│  │  - Spot interruption: Graceful workspace migration to on-demand              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Template Architecture

The Coder platform uses a two-layer template architecture separating portable toolchain definitions from instance-specific infrastructure.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        Template Composition Model                                    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                  Toolchain Layer (Portable)                                  │    │
│  │                                                                              │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │ swdev-toolchain │  │windev-toolchain │  │datasci-toolchain│              │    │
│  │  │                 │  │                 │  │                 │              │    │
│  │  │ Languages:      │  │ Languages:      │  │ Languages:      │              │    │
│  │  │  Go, Node, Py   │  │  C#, .NET       │  │  Python, R      │              │    │
│  │  │ Tools:          │  │ Tools:          │  │ Tools:          │              │    │
│  │  │  terraform,     │  │  Visual Studio, │  │  Jupyter, CUDA  │              │    │
│  │  │  kubectl, gh    │  │  Git, Azure CLI │  │  PyTorch, TF    │              │    │
│  │  │ Capabilities:   │  │ Capabilities:   │  │ Capabilities:   │              │    │
│  │  │  persistent-    │  │  gui-rdp,       │  │  gpu-optional,  │              │    │
│  │  │  home, https    │  │  persistent-    │  │  persistent-    │              │    │
│  │  │  egress         │  │  home           │  │  home, https    │              │    │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘              │    │
│  └───────────┼────────────────────┼────────────────────┼───────────────────────┘    │
│              │                    │                    │                            │
│              ▼                    ▼                    ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                 Template Contract (Capability Interface)                     │    │
│  │                                                                              │    │
│  │  Inputs:  workspace_name, owner, compute_profile, image_id                  │    │
│  │  Outputs: agent_endpoint, env_vars, volume_mounts, metadata                 │    │
│  │  Capabilities: compute, network, storage, identity, secrets                 │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│              │                    │                    │                            │
│              ▼                    ▼                    ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │              Infrastructure Base Layer (Instance-Specific)                   │    │
│  │                                                                              │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │    │
│  │  │    base-k8s     │  │ base-ec2-linux  │  │ base-ec2-windows│              │    │
│  │  │                 │  │                 │  │                 │              │    │
│  │  │ - Namespace     │  │ - AMI selection │  │ - Windows AMI   │              │    │
│  │  │ - Node pool     │  │ - IAM roles     │  │ - DCV/WebRDP    │              │    │
│  │  │ - PVC/Storage   │  │ - Security grps │  │ - IAM roles     │              │    │
│  │  │ - NetworkPolicy │  │ - EBS volumes   │  │ - Security grps │              │    │
│  │  │ - Service acct  │  │ - KasmVNC opt   │  │ - EBS volumes   │              │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │    │
│  │                                                                              │    │
│  │  ┌─────────────────┐                                                         │    │
│  │  │  base-ec2-gpu   │                                                         │    │
│  │  │                 │                                                         │    │
│  │  │ - GPU AMI       │                                                         │    │
│  │  │ - g4dn/g5/p3/p4 │                                                         │    │
│  │  │ - CUDA drivers  │                                                         │    │
│  │  └─────────────────┘                                                         │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  Composition: Final Template = Toolchain + Base + Overrides                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Template Pairings

| Use Case | Toolchain | Infrastructure Base | Result |
|----------|-----------|---------------------|--------|
| Pod-based SW dev | swdev-toolchain | base-k8s | pod-swdev |
| Windows dev | windev-toolchain | base-ec2-windows | ec2-windev-gui |
| Data science (CPU) | datasci-toolchain | base-ec2-linux | ec2-datasci |
| Data science (GPU) | datasci-toolchain | base-ec2-gpu | ec2-datasci-gpu |

### Workspace T-Shirt Sizes

| Size | vCPU | RAM | Storage | Target User |
|------|------|-----|---------|-------------|
| SW Dev Small | 2 | 4GB | 20GB | Light development |
| SW Dev Medium | 4 | 8GB | 50GB | Standard development |
| SW Dev Large | 8 | 16GB | 100GB | Heavy development |
| Platform/DevSecOps | 4 | 8GB | 100GB | Infrastructure work |
| Data Sci Standard | 8 | 32GB | 500GB | Data analysis |
| Data Sci Large | 16 | 64GB | 1TB | ML training (GPU opt) |
| Data Sci XLarge | 32 | 64GB | 2TB | Large ML (1-N GPUs) |

## Next Steps

- **Prerequisites**: Review [Prerequisites and Quota Requirements](prerequisites.md) before deployment
- **Deployment**: Follow the [Day 0: Infrastructure Deployment](../operations/day0-deployment.md) guide
- **Operations**: Review [Day 2: Ongoing Operations](../operations/day2-operations.md) for maintenance procedures

## Related Documentation

- [Prerequisites and Quota Requirements](prerequisites.md)
- [Day 0: Infrastructure Deployment](../operations/day0-deployment.md)
- [Day 1: Initial Configuration](../operations/day1-configuration.md)
- [Day 2: Ongoing Operations](../operations/day2-operations.md)
- [Template Architecture README](../../terraform/modules/coder/template-architecture/README.md)

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
