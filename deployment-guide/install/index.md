# Installation

This guide walks through installing Coder on your AWS EKS cluster using Helm.

> [!NOTE]
> Ensure you have completed all [prerequisites](../prerequisites/index.md)
> before proceeding.

## Overview

The installation process consists of:

1. Creating a Kubernetes namespace
2. Configuring database credentials
3. Deploying Coder via Helm
4. Configuring the load balancer
5. Verifying the installation

## Create Namespace

Create a dedicated namespace for Coder:

```bash
kubectl create namespace coder
```

## Configure Database Secret

Create a Kubernetes secret with your PostgreSQL connection string:

```bash
kubectl create secret generic coder-db-url \
  --namespace coder \
  --from-literal=url="postgres://coder:<password>@<rds-endpoint>:5432/coder?sslmode=require"
```

## Install Coder with Helm

Add the Coder Helm repository:

```bash
helm repo add coder-v2 https://helm.coder.com/v2
helm repo update
```

Create a `values.yaml` file for your deployment:

```yaml
coder:
  env:
    - name: CODER_PG_CONNECTION_URL
      valueFrom:
        secretKeyRef:
          name: coder-db-url
          key: url
    - name: CODER_ACCESS_URL
      value: "https://coder.example.com"
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local
    sessionAffinity: None
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

Install Coder:

```bash
helm install coder coder-v2/coder \
  --namespace coder \
  --values values.yaml
```

## Verify Installation

Check that Coder pods are running:

```bash
kubectl get pods --namespace coder
```

Get the load balancer address:

```bash
kubectl get svc --namespace coder
```

## Next Steps

- [Configure TLS](../configuration/index.md#tls)
- [Set up authentication](../configuration/index.md#authentication)
- [Create your first template](../configuration/index.md#templates)
