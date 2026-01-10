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
- `git_pat`: Your GitHub Personal Access Token (Classic) with `repo` and `read:packages` scope. This allows Argo CD to access the repo and K3s to pull private images.
- `git_username`: Your GitHub username (used for GHCR image paths).
- `git_repo_name`: The name of this repository (default `k3s-oracle`).

## 3. Provisioning

Run Terraform to provision infrastructure and generate the Kubernetes manifests (with your domain and config).

```bash
cd tf-k3s
terraform init
terraform apply -auto-approve
```

**CRITICAL STEP**: Terraform generates the GitOps manifests in the `argocd/` directory. You **MUST** commit and push these changes so the cluster can sync them.

```bash
cd ..
git add argocd/
git commit -m "Configure cluster manifests"
git push
```

## 4. Bootstrapping (Automatic)

Terraform uses `cloud-init` to:

1. Set up software NAT on the Ingress node.
2. Install K3s on the Server node.
3. Install K3s Agent on the Worker node.
4. Install Argo CD and the Root Application.

**Time to wait**: ~5 minutes for all nodes to join and Argo CD to start syncing.
