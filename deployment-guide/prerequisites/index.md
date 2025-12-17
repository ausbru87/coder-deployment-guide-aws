# Prerequisites

Gather the following before deploying Coder on AWS.

> This guide is opinionated for **500 peak concurrent workspaces**.

## Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [AWS CLI](https://aws.amazon.com/cli/) | 2.x | AWS resource management |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | ±1 minor of EKS | Kubernetes management |
| [Helm](https://helm.sh/docs/intro/install/) | 3.5+ | Coder deployment |
| [coder CLI](https://coder.com/docs/install) | latest | Template management, admin tasks |
| [eksctl](https://eksctl.io/) | latest | EKS cluster creation |

Verify installations:

```bash
aws --version
kubectl version --client
helm version
coder version
eksctl version
```

## AWS Account

### Region

Select your target region. This guide uses `us-west-2` in examples.

### IAM Permissions

Your IAM user or role must have the following permissions:

| Service | Actions |
|---------|---------|
| **EC2 / VPC** | `CreateVpc`, `DeleteVpc`, `CreateSubnet`, `DeleteSubnet`, `CreateRouteTable`, `DeleteRouteTable`, `CreateRoute`, `DeleteRoute`, `AssociateRouteTable`, `DisassociateRouteTable`, `CreateInternetGateway`, `DeleteInternetGateway`, `AttachInternetGateway`, `DetachInternetGateway`, `CreateNatGateway`, `DeleteNatGateway`, `AllocateAddress`, `ReleaseAddress`, `CreateSecurityGroup`, `DeleteSecurityGroup`, `AuthorizeSecurityGroupIngress`, `AuthorizeSecurityGroupEgress`, `RevokeSecurityGroupIngress`, `RevokeSecurityGroupEgress`, `CreateVpcEndpoint`, `DeleteVpcEndpoints`, `CreateTags`, `DeleteTags`, `Describe*` |
| **EKS** | `CreateCluster`, `DeleteCluster`, `UpdateClusterConfig`, `UpdateClusterVersion`, `CreateNodegroup`, `DeleteNodegroup`, `UpdateNodegroupConfig`, `CreateAddon`, `DeleteAddon`, `UpdateAddon`, `AssociateIdentityProviderConfig`, `CreateAccessEntry`, `Describe*`, `List*` |
| **RDS** | `CreateDBInstance`, `DeleteDBInstance`, `ModifyDBInstance`, `CreateDBSubnetGroup`, `DeleteDBSubnetGroup`, `CreateDBParameterGroup`, `DeleteDBParameterGroup`, `Describe*`, `List*`, `AddTagsToResource` |
| **ELB** | `CreateLoadBalancer`, `DeleteLoadBalancer`, `CreateTargetGroup`, `DeleteTargetGroup`, `CreateListener`, `DeleteListener`, `ModifyLoadBalancerAttributes`, `ModifyTargetGroupAttributes`, `RegisterTargets`, `DeregisterTargets`, `Describe*` |
| **IAM** | `CreateRole`, `DeleteRole`, `AttachRolePolicy`, `DetachRolePolicy`, `PutRolePolicy`, `DeleteRolePolicy`, `CreatePolicy`, `DeletePolicy`, `CreateInstanceProfile`, `DeleteInstanceProfile`, `AddRoleToInstanceProfile`, `RemoveRoleFromInstanceProfile`, `CreateOpenIDConnectProvider`, `DeleteOpenIDConnectProvider`, `PassRole`, `GetRole`, `ListRoles`, `ListPolicies`, `GetPolicy`, `GetPolicyVersion` |
| **ACM** | `RequestCertificate`, `DeleteCertificate`, `DescribeCertificate`, `ListCertificates`, `AddTagsToCertificate` |
| **Route 53** | `CreateHostedZone`, `ChangeResourceRecordSets`, `GetHostedZone`, `ListHostedZones`, `ListResourceRecordSets`, `GetChange` |
| **Secrets Manager** | `CreateSecret`, `DeleteSecret`, `GetSecretValue`, `PutSecretValue`, `UpdateSecret`, `DescribeSecret`, `ListSecrets`, `TagResource` |
| **Auto Scaling** | `CreateAutoScalingGroup`, `DeleteAutoScalingGroup`, `UpdateAutoScalingGroup`, `CreateLaunchConfiguration`, `DeleteLaunchConfiguration`, `Describe*`, `SetDesiredCapacity`, `TerminateInstanceInAutoScalingGroup` |
| **CloudFormation** | `CreateStack`, `DeleteStack`, `UpdateStack`, `DescribeStacks`, `DescribeStackEvents`, `ListStacks` (required by eksctl) |
| **SSM** | `GetParameter`, `GetParameters` (required by eksctl for AMI lookup) |

<details>
<summary>Example IAM policy (broad, scope down after deployment)</summary>

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:*",
      "eks:*",
      "rds:*",
      "elasticloadbalancing:*",
      "iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:CreatePolicy", "iam:DeletePolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
      "iam:PassRole", "iam:GetRole", "iam:ListRoles", "iam:ListPolicies",
      "iam:GetPolicy", "iam:GetPolicyVersion",
      "acm:*",
      "route53:*",
      "secretsmanager:*",
      "autoscaling:*",
      "cloudformation:*",
      "ssm:GetParameter", "ssm:GetParameters"
    ],
    "Resource": "*"
  }]
}
```
</details>

### Service Quotas

Verify these quotas in your target region before deployment:

| Quota | Code | Default | Required | Action |
|-------|------|---------|----------|--------|
| EC2 On-Demand Standard vCPUs | `L-1216C47A` | 5 | **≥3,000** | 🔴 Request increase |
| EBS gp3 storage (TiB) | `L-7A658B76` | 50 | 18 | ✅ Sufficient |
| EBS volumes | `L-D18FCD1D` | 5,000 | 600 | ✅ Sufficient |
| VPC Elastic IPs | `L-0263D0A3` | 5 | 1 | ✅ Sufficient |
| Network interfaces (ENIs) | `L-DF5E4CA3` | 5,000 | ~400 | ✅ Sufficient |
| EKS nodes per node group | `L-BD136F5B` | 450 | ~50 | ✅ Sufficient |
| RDS DB instances | — | 40 | 1 | ✅ Sufficient |

Check your current vCPU quota:

```bash
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-west-2
```

Request increase if needed (1-2 business days for approval):

```bash
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 3000 \
  --region us-west-2
```

## Workspace Sizing

This guide uses the following t-shirt sizes and distribution:

| Size | vCPU | RAM | Distribution |
|------|------|-----|--------------|
| S | 2 | 4 GB | 25% |
| M | 4 | 8 GB | 60% |
| L | 8 | 16 GB | 15% |

These estimates drive node pool sizing in the infrastructure setup.

## Domain & DNS

- **Base domain** (e.g., `example.com`) — must be a hosted zone in Route 53
- **Coder subdomain** (e.g., `coder.example.com`) — will be configured as `CODER_ACCESS_URL` during installation

If your base domain is registered elsewhere, [delegate to Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/migrate-dns-domain-in-use.html) or create a subdomain hosted zone.

## Authentication

Coder requires an identity provider for production use.

- Your SSO provider must support **OpenID Connect (OIDC)**
- Have client ID and client secret ready
- See [Coder OIDC documentation](https://coder.com/docs/admin/auth#openid-connect) for provider requirements

## Checklist

- [ ] Tools installed: AWS CLI, kubectl, Helm, coder CLI, eksctl
- [ ] AWS CLI configured (`aws sts get-caller-identity` works)
- [ ] IAM permissions verified (see IAM Permissions section above)
- [ ] Region selected
- [ ] Domain is a Route 53 hosted zone
- [ ] OIDC provider configured with client credentials
- [ ] EC2 vCPU quota ≥3,000 (or increase requested)

## Next Steps

Proceed to [Infrastructure Setup](../install/infrastructure.md).
