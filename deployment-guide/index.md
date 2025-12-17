# Deploying Coder on AWS

This guide covers deploying Coder to Amazon Web Services (AWS) using Amazon
Elastic Kubernetes Service (EKS).

## Overview

Coder is an open-source platform for creating and managing developer workspaces
on your infrastructure. When deployed on AWS, Coder runs on an EKS cluster and
provisions workspaces as Kubernetes pods, EC2 instances, or other AWS resources.

## Architecture

A typical AWS deployment consists of:

- **Amazon EKS cluster** - Hosts the Coder control plane (`coderd`)
- **Amazon RDS for PostgreSQL** - Stores Coder metadata and state
- **Network Load Balancer** - Routes traffic to the Coder service
- **Amazon VPC** - Provides network isolation and security

## Deployment Steps

1. [Prerequisites](prerequisites/index.md) - Verify you have the required
   accounts, tools, and permissions
2. [Installation](install/index.md) - Deploy Coder to your EKS cluster
3. [Configuration](configuration/index.md) - Configure authentication, TLS, and
   other settings
4. [Troubleshooting](troubleshooting/index.md) - Resolve common issues

## Next Steps

Begin by reviewing the [prerequisites](prerequisites/index.md) to ensure your
environment is ready for installation.
