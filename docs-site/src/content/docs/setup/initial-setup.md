---
title: Cluster Setup Guide
---

# Initial Cluster Setup

This page covers how to stand up the cluster from zero using Terraform.

## 1. Prerequisites

- OCI Account (Always Free).
- Cloudflare Domain & API Token.
- `terraform` and `gh` (GitHub CLI) installed locally.

## 2. Configuration

Create `tf-k3s/terraform.tfvars`. Ensure the following variables are set:

- `tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key_path`.
- `cloudflare_api_token`, `domain_name`, `acme_email`.
- `git_repo_url`: The URL of **this** repository.

## 3. Provisioning

```bash
cd tf-k3s
terraform init
terraform apply -auto-approve
```

## 4. Bootstrapping (Automatic)

Terraform uses `cloud-init` to:

1. Set up software NAT on the Ingress node.
2. Install K3s on the Server node.
3. Install K3s Agent on the Worker node.
4. Install Argo CD and the Root Application.

**Time to wait**: ~5 minutes for all nodes to join and Argo CD to start syncing.
