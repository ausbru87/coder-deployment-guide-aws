# Troubleshooting

Common issues and solutions when deploying Coder on AWS.

## Load Balancer Issues

### External IP Stuck in Pending State

**Symptom**: The Coder service shows `<pending>` for the external IP.

**Solution**: Ensure `sessionAffinity` is set to `None`:

```yaml
coder:
  service:
    type: LoadBalancer
    sessionAffinity: None
```

### Classic Load Balancer Instead of NLB

**Symptom**: AWS creates a Classic Load Balancer instead of a Network Load
Balancer.

**Solution**: Add the NLB annotation:

```yaml
coder:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

## Database Connectivity

### Connection Refused

**Symptom**: Coder pods fail to start with database connection errors.

**Solutions**:

1. Verify the RDS security group allows inbound traffic on port 5432 from the
   EKS node security group
2. Confirm the RDS instance is in the same VPC as the EKS cluster
3. Check the connection string format in your Kubernetes secret

### SSL/TLS Errors

**Symptom**: Database connection fails with SSL errors.

**Solution**: Ensure `sslmode=require` is in your connection string:

```
postgres://user:password@endpoint:5432/database?sslmode=require
```

## Network Issues

### Workspace Connectivity Problems

**Symptom**: Workspaces can't establish direct connections.

**Solution**: Configure the VPC CNI to disable SNAT randomization:

```bash
kubectl set env daemonset aws-node \
  --namespace kube-system \
  AWS_VPC_K8S_CNI_RANDOMIZESNAT=none
```

## Pod Issues

### Pods Stuck in Pending

**Symptom**: Coder pods remain in `Pending` state.

**Solutions**:

1. Check for resource constraints: `kubectl describe pod <pod-name> -n coder`
2. Verify node capacity: `kubectl describe nodes`
3. Check for PersistentVolumeClaim issues

### Pods CrashLooping

**Symptom**: Coder pods restart repeatedly.

**Solution**: Check pod logs for errors:

```bash
kubectl logs -n coder deployment/coder --previous
```

## Getting Help

If you're still experiencing issues:

1. Check the [Coder documentation](https://coder.com/docs)
2. Search [GitHub issues](https://github.com/coder/coder/issues)
3. Join the [Coder Discord community](https://discord.gg/coder)
