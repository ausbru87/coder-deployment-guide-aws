# EKS Authentication for AWS Secrets Manager - Decision Log

## Summary
Testing various approaches to integrate AWS Secrets Manager with EKS for Coder deployment.

## Approaches Tested

| Approach | Components | Status | Issues | Notes |
|----------|------------|--------|--------|-------|
| **CSI Secrets Store + Pod Identity** | Manual CSI driver + Manual ASCP v2.1.0 + Pod Identity | ❌ Failed | "IAM role must be associated" despite Pod Identity working | Pod Identity credentials not recognized by AWS SDK |
| **External Secrets Operator + Pod Identity** | ESO v0.x + Pod Identity | ❌ Failed | "IAM role must be associated" despite Pod Identity working | Same Pod Identity SDK compatibility issue |
| **CSI Secrets Store + Pod Identity (v1.0.1)** | Manual CSI driver + Manual ASCP v1.0.1 + Pod Identity | ❌ Failed | "provider not found" then "IAM role must be associated" | Version downgrade didn't resolve Pod Identity issue |
| **Managed EKS Add-on + Pod Identity** | AWS managed add-on v2.1.1-eksbuild.1 + Pod Identity | ⚠️ Partially Working | "IAM role must be associated" despite Pod Identity working | Add-on installs correctly, Pod Identity still not recognized |
| **Managed EKS Add-on + IRSA** | AWS managed add-on v2.1.1-eksbuild.1 + IRSA | ✅ **SUCCESS** | CSI driver lacks secret creation permissions | **Authentication works, secrets retrieved successfully** |

## Key Findings

### What Worked ✅
- **Pod Identity associations** created successfully
- **Pod Identity tokens** injected into pods correctly
- **AWS environment variables** present in pods
- **Managed EKS add-on** installation and CSI driver communication
- **SecretProviderClass** configuration correct
- **AWS Secrets Manager** secrets accessible via CLI
- **IRSA authentication** recognized by AWS SDK in managed add-on
- **Secret retrieval** from AWS Secrets Manager successful
- **CSI volume mounting** working correctly

### What Didn't Work ❌
- **Pod Identity authentication** not recognized by AWS SDK in any CSI/ESO component
- **Manual ASCP installations** had provider registration issues
- **Version compatibility** between CSI driver and ASCP when installed separately
- **Kubernetes secret creation** due to CSI driver service account permissions

### Root Cause Analysis
1. **Pod Identity**: AWS SDK compatibility issues across all tested components
2. **Manual installations**: Provider registration and version compatibility problems
3. **Managed add-on**: Works perfectly for authentication and secret retrieval, minor RBAC issue

## Final Recommendation: IRSA with Managed Add-on ✅

**Chosen Approach**: IRSA (IAM Roles for Service Accounts) with AWS managed EKS add-on

**Rationale**:
- Managed add-on ensures compatibility between CSI driver and AWS provider
- IRSA has proven compatibility with CSI Secrets Store components
- AWS documentation shows IRSA as the mature, widely-supported approach
- Avoids Pod Identity SDK compatibility issues

## Next Steps
1. Configure OIDC provider for IRSA
2. Create IAM role with trust policy for IRSA
3. Associate IAM role with service account via annotations
4. Test secret mounting with managed add-on + IRSA
