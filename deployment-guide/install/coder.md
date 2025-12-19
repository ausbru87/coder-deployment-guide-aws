# Coder Installation

This guide walks through installing Coder on your AWS EKS cluster using Helm.

> [!NOTE]
> Complete [prerequisites](../prerequisites/index.md) and
> [infrastructure](infrastructure.md) before proceeding.

## Overview

The installation process consists of:

1. Creating a Kubernetes namespace
2. Installing the Secrets Store CSI Driver
3. Configuring the SecretProviderClass
4. Deploying Coder via Helm
5. Configuring DNS
6. Verifying the installation

## Create Namespace

```bash
kubectl create namespace coder
```

## Install Secrets Store CSI Driver

Install the CSI driver to sync secrets from AWS Secrets Manager:

```bash
# Install Secrets Store CSI Driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update

helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true

# Install AWS Provider
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

Verify:

```bash
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws
```

## Create SecretProviderClass

Create the SecretProviderClass to sync secrets from AWS Secrets Manager:

```bash
source coder-infra.env

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: coder-secrets
  namespace: coder
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "coder/database-url"
        objectType: "secretsmanager"
      - objectName: "coder/github-client-id"
        objectType: "secretsmanager"
      - objectName: "coder/github-client-secret"
        objectType: "secretsmanager"
      - objectName: "coder/github-allowed-orgs"
        objectType: "secretsmanager"
  secretObjects:
  - secretName: coder-secrets
    type: Opaque
    data:
    - objectName: "coder/database-url"
      key: db-url
    - objectName: "coder/github-client-id"
      key: github-client-id
    - objectName: "coder/github-client-secret"
      key: github-client-secret
    - objectName: "coder/github-allowed-orgs"
      key: github-allowed-orgs
EOF
```

## Install Coder with Helm

Add the Coder Helm repository:

```bash
helm repo add coder-v2 https://helm.coder.com/v2
helm repo update
```

> [!NOTE]
> This guide uses **GitHub OAuth** for authentication for simplicity. Coder supports many other identity providers including Okta, Azure AD, and any OIDC-compliant provider.
> See [Coder OIDC documentation](https://coder.com/docs/admin/users/oidc-auth) for alternatives.

Create a `values.yaml` file:

```bash
source coder-infra.env

cat <<EOF > values.yaml
coder:
  # -- Service account configuration
  serviceAccount:
    create: true
    name: coder
    workspacePerms: true
    enableDeployments: true
  
  # -- Image configuration
  image:
    repo: "ghcr.io/coder/coder"
    pullPolicy: IfNotPresent
  
  # -- Number of coderd replicas for HA (requires Enterprise license)
  replicaCount: 2
  
  # -- Schedule coderd on coder-system nodes (tainted)
  nodeSelector:
    coder/node-type: coderd
  tolerations:
    - key: "coder/node-type"
      operator: "Equal"
      value: "coderd"
      effect: "NoSchedule"
  
  # -- Resource requests/limits for coderd
  resources:
    requests:
      cpu: "2000m"
      memory: "4Gi"
    limits:
      cpu: "4000m"
      memory: "8Gi"
  
  # -- Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
  
  # -- Environment variables
  env:
    # Database
    - name: CODER_PG_CONNECTION_URL
      valueFrom:
        secretKeyRef:
          name: coder-secrets
          key: db-url
    # Access URLs
    - name: CODER_ACCESS_URL
      value: "https://${CODER_DOMAIN}"
    - name: CODER_WILDCARD_ACCESS_URL
      value: "https://*.${CODER_DOMAIN}"
    # Observability
    - name: CODER_PROMETHEUS_ENABLE
      value: "true"
    # Logging
    - name: CODER_VERBOSE
      value: "false"
    # Disable built-in provisioners (external only)
    - name: CODER_PROVISIONER_DAEMONS
      value: "0"
    # GitHub OAuth - see "Configure Authentication" section below
    - name: CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS
      value: "true"
    - name: CODER_OAUTH2_GITHUB_ALLOWED_ORGS
      valueFrom:
        secretKeyRef:
          name: coder-secrets
          key: github-allowed-orgs
    - name: CODER_OAUTH2_GITHUB_CLIENT_ID
      valueFrom:
        secretKeyRef:
          name: coder-secrets
          key: github-client-id
    - name: CODER_OAUTH2_GITHUB_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-secrets
          key: github-client-secret
  
  # -- Service configuration
  service:
    enable: true
    type: LoadBalancer
    sessionAffinity: None
    externalTrafficPolicy: Cluster
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${CERT_ARN}"
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
  
  # -- Secrets Store CSI volume for credentials
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: coder-secrets
  volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
  
  # -- Pod anti-affinity for HA (requires replicas on separate nodes)
  # Using 'required' because coderd uses round-robin load balancing;
  # a downed pod disrupts users relaying through it.
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/instance
                operator: In
                values:
                  - coder
          topologyKey: kubernetes.io/hostname
EOF

cat values.yaml
```

Install Coder:

```bash
helm install coder coder-v2/coder \
  --namespace coder \
  --values values.yaml
```

Create a PodDisruptionBudget to prevent eviction storms during node drains/upgrades:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: coder-pdb
  namespace: coder
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: coder
EOF
```

## Configure DNS

Get the NLB hostname and create a DNS record:

```bash
source coder-infra.env

# Wait for load balancer to be provisioned
kubectl get svc coder -n coder -w

# Get the NLB hostname
NLB_HOSTNAME=$(kubectl get svc coder -n coder \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "NLB Hostname: $NLB_HOSTNAME"

# Get hosted zone ID
BASE_DOMAIN=$(echo $CODER_DOMAIN | cut -d. -f2-)
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name $BASE_DOMAIN \
  --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)

# Create A record (alias to NLB)
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "'$CODER_DOMAIN'",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z18D5FSROUN65G",
        "DNSName": "'$NLB_HOSTNAME'",
        "EvaluateTargetHealth": true
      }
    }
  }]
}'
```

> [!NOTE]
> The `HostedZoneId` for NLB varies by region. `Z18D5FSROUN65G` is for `us-west-2`.
> See [AWS docs](https://docs.aws.amazon.com/general/latest/gr/elb.html) for other regions.

## Verify Installation

```bash
# Check pods are running
kubectl get pods -n coder

# Check secret was synced from Secrets Manager
kubectl get secret coder-db-url -n coder

# Check service has external IP
kubectl get svc -n coder

# Test access (may take a few minutes for DNS propagation)
curl -I https://$CODER_DOMAIN
```

Expected output:
- Pods: `Running` status
- Secret: `coder-db-url` exists
- Service: External hostname assigned
- curl: HTTP 200 or redirect

## Create First User

Open `https://<your-coder-domain>` in a browser to create the first admin user.

## Deploy External Provisioners

This deployment uses external provisioners running on dedicated `coder-provisioner` nodes. The coderd pods have `CODER_PROVISIONER_DAEMONS=0` to disable built-in provisioners.

### 1. Create Provisioner Key

After coderd is running, create a provisioner key:

```bash
coder provisioner keys create eks-provisioner --tag scope=organization

# Save the output key for the next step
```

### 2. Create Kubernetes Secret

```bash
kubectl create secret generic coder-provisioner-key \
  --namespace coder \
  --from-literal=key="<provisioner-key-from-step-1>"
```

### 3. Create Provisioner Values File

```bash
source coder-infra.env

cat <<EOF > provisioner-values.yaml
coder:
  serviceAccount:
    workspacePerms: true
    enableDeployments: true
    name: coder-provisioner

  image:
    repo: "ghcr.io/coder/coder"
    pullPolicy: IfNotPresent

  replicaCount: 2

  nodeSelector:
    coder/node-type: provisioner
  tolerations:
    - key: "coder/node-type"
      operator: "Equal"
      value: "provisioner"
      effect: "NoSchedule"

  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "4000m"
      memory: "8Gi"

  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault

  env:
    - name: CODER_URL
      value: "https://${CODER_DOMAIN}"
    - name: CODER_PROVISIONER_DAEMONS
      value: "10"
    - name: CODER_VERBOSE
      value: "false"
    - name: CODER_PROMETHEUS_ENABLE
      value: "true"

  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/instance
                  operator: In
                  values:
                    - coder-provisioner
            topologyKey: kubernetes.io/hostname
          weight: 1

provisionerDaemon:
  keySecretName: "coder-provisioner-key"
  keySecretKey: "key"
  terminationGracePeriodSeconds: 600
EOF

cat provisioner-values.yaml
```

### 4. Install Provisioner Chart

```bash
helm install coder-provisioner coder-v2/coder-provisioner \
  --namespace coder \
  --values provisioner-values.yaml
```

### 5. Verify Provisioners

```bash
kubectl get pods -n coder -l app.kubernetes.io/name=coder-provisioner

# Check provisioner logs
kubectl logs -n coder -l app.kubernetes.io/name=coder-provisioner --tail=50
```

### Capacity Planning

| Setting | Value | Result |
|---------|-------|--------|
| `replicaCount` | 2 pods | |
| `CODER_PROVISIONER_DAEMONS` | 10 per pod | |
| **Total** | | **20 concurrent builds** |

For 500 workspaces, 20 concurrent builds handles typical morning startup surges. Adjust `replicaCount` or `CODER_PROVISIONER_DAEMONS` if you see build queuing.

## Configure Authentication (GitHub OAuth)

> [!NOTE]
> You can skip this section for initial testing. Coder provides a default GitHub app for convenience.
> For production, configure your own OAuth app to avoid sharing data with Coder (the company).

See [Coder GitHub Auth docs](https://coder.com/docs/admin/users/github-auth) for full details.

### 1. Create GitHub OAuth App

1. Go to GitHub → Settings → Developer settings → OAuth Apps → New OAuth App
2. Set **Homepage URL** to `https://${CODER_DOMAIN}`
3. Set **Authorization callback URL** to `https://${CODER_DOMAIN}`
4. Note the **Client ID** and generate a **Client Secret**

### 2. Store Credentials in Secrets Manager

```bash
source coder-infra.env

# Set your GitHub OAuth credentials
export GH_ORG="your-github-org"
export GH_CLIENT_ID="your-client-id"
export GH_CLIENT_SECRET="your-client-secret"

# Store GitHub OAuth credentials
aws secretsmanager create-secret \
  --name coder/github-allowed-orgs \
  --secret-string "$GH_ORG" \
  --region $AWS_REGION

aws secretsmanager create-secret \
  --name coder/github-client-id \
  --secret-string "$GH_CLIENT_ID" \
  --region $AWS_REGION

aws secretsmanager create-secret \
  --name coder/github-client-secret \
  --secret-string "$GH_CLIENT_SECRET" \
  --region $AWS_REGION
```

### 3. Update SecretProviderClass

Update the SecretProviderClass to include GitHub credentials:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: coder-secrets
  namespace: coder
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "coder/database-url"
        objectType: "secretsmanager"
      - objectName: "coder/github-client-id"
        objectType: "secretsmanager"
      - objectName: "coder/github-client-secret"
        objectType: "secretsmanager"
      - objectName: "coder/github-allowed-orgs"
        objectType: "secretsmanager"
  secretObjects:
  - secretName: coder-secrets
    type: Opaque
    data:
    - objectName: "coder/database-url"
      key: db-url
    - objectName: "coder/github-client-id"
      key: github-client-id
    - objectName: "coder/github-client-secret"
      key: github-client-secret
    - objectName: "coder/github-allowed-orgs"
      key: github-allowed-orgs
EOF
```

### 4. Add Environment Variables to values.yaml

Add these to your `values.yaml` env section:

```yaml
    - name: CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS
      value: "true"
    - name: CODER_OAUTH2_GITHUB_ALLOWED_ORGS
      value: "your-github-org"
    - name: CODER_OAUTH2_GITHUB_CLIENT_ID
      valueFrom:
        secretKeyRef:
          name: coder-secrets
          key: github-client-id
    - name: CODER_OAUTH2_GITHUB_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-secrets
          key: github-client-secret
```

### 5. Upgrade Coder

```bash
helm upgrade coder coder-v2/coder \
  --namespace coder \
  --values values.yaml
```

## Workspace Node Scheduling

Workspaces should run on `coder-ws` nodes, not on system nodes. Configure your Terraform templates to use the workspace node selector:

```hcl
# In your Coder Terraform template
resource "kubernetes_deployment" "workspace" {
  # ...
  spec {
    template {
      spec {
        node_selector = {
          "coder/node-type" = "workspace"
        }
        # ...
      }
    }
  }
}
```

Or for Docker-based templates using `kubernetes_pod`:

```hcl
resource "kubernetes_pod" "workspace" {
  # ...
  spec {
    node_selector = {
      "coder/node-type" = "workspace"
    }
    # ...
  }
}
```

This ensures:
- **coderd** runs on `coder-system` nodes (via Helm values)
- **workspaces** run on `coder-ws` nodes (via template config)
- **provisioners** can run on `coder-prov` nodes (if using external provisioners)

## Next Steps

- [Configure authentication](../configuration/index.md#authentication)
- [Create your first template](../configuration/index.md#templates)
- [Set up workspace quotas](../configuration/index.md#quotas)
