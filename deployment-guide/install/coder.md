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

Create the SecretProviderClass to sync the database URL from Secrets Manager:

```bash
source coder-infra.env

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: coder-db-secret
  namespace: coder
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "coder/database-url"
        objectType: "secretsmanager"
  secretObjects:
  - secretName: coder-db-url
    type: Opaque
    data:
    - objectName: "coder/database-url"
      key: url
EOF
```

## Install Coder with Helm

Add the Coder Helm repository:

```bash
helm repo add coder-v2 https://helm.coder.com/v2
helm repo update
```

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
  
  # -- Number of replicas (1 for MVP, increase for HA - Enterprise feature)
  replicaCount: 1
  
  # -- Schedule coderd on coder-system nodes
  nodeSelector:
    coder.com/node-type: system
  
  # -- Resource requests/limits for coderd
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
  
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
    - name: CODER_PG_CONNECTION_URL
      valueFrom:
        secretKeyRef:
          name: coder-db-url
          key: url
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
  
  # -- Secrets Store CSI volume for database credentials
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: coder-db-secret
  volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
  
  # -- Pod anti-affinity for HA (spreads replicas across nodes)
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/instance
                  operator: In
                  values:
                    - coder
            topologyKey: kubernetes.io/hostname
          weight: 1
EOF

cat values.yaml
```

Install Coder:

```bash
helm install coder coder-v2/coder \
  --namespace coder \
  --values values.yaml
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
          "coder.com/node-type" = "workspace"
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
      "coder.com/node-type" = "workspace"
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
