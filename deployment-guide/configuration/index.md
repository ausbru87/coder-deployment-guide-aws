# Configuration

After installing Coder, configure these settings for a production-ready
deployment.

## Access URL

`CODER_ACCESS_URL` is the most critical configuration—it's the URL users use to
access Coder and must be set correctly for workspaces to connect.

```yaml
coder:
  env:
    - name: CODER_ACCESS_URL
      value: "https://coder.example.com"
```

After getting your load balancer address (`kubectl get svc -n coder`), create a
DNS record pointing your domain to it.

## TLS

Configure TLS to secure access to your Coder deployment.

### Using AWS Certificate Manager

If you're using an AWS Network Load Balancer with ACM:

```yaml
coder:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "<acm-certificate-arn>"
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
```

### Using cert-manager

For automatic certificate management with Let's Encrypt, install cert-manager
and configure an Ingress resource.

## Authentication

Coder supports multiple authentication providers:

- Built-in username/password
- OpenID Connect (OIDC)
- GitHub OAuth
- GitLab OAuth

### OIDC Configuration

```yaml
coder:
  env:
    - name: CODER_OIDC_ISSUER_URL
      value: "https://your-idp.example.com"
    - name: CODER_OIDC_CLIENT_ID
      value: "<client-id>"
    - name: CODER_OIDC_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-oidc
          key: client-secret
```

## Templates

After installation, create workspace templates to define your development
environments. See the [Coder templates documentation](https://coder.com/docs/templates)
for details.

## Next Steps

- Review [troubleshooting](../troubleshooting/index.md) for common issues
- Explore [Coder documentation](https://coder.com/docs) for advanced configuration
