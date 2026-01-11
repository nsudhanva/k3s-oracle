---
title: Configuration
description: Setting up Terraform variables for cluster deployment
---

import { Aside } from '@astrojs/starlight/components';

Create `tf-k3s/terraform.tfvars` with your environment-specific values. This file is gitignored and should never be committed.

<Aside type="tip">
  After initial deployment, all secrets are stored in OCI Vault. See [Secrets Management](/architecture/secrets-management) for retrieval instructions.
</Aside>

## Required Variables

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaaa..."
user_ocid        = "ocid1.user.oc1..aaaa..."
fingerprint      = "12:34:56:..."
private_key_path = "/path/to/oci_api_key.pem"
compartment_ocid = "ocid1.compartment.oc1..aaaa..."
region           = "us-ashburn-1"

ssh_public_key_path  = "/path/to/ssh_key.pub"
cloudflare_api_token = "your-cloudflare-token"
cloudflare_zone_id   = "your-zone-id"
domain_name          = "k3s.yourdomain.com"
acme_email           = "admin@yourdomain.com"

git_repo_url  = "https://github.com/your-username/k3s-oracle.git"
git_username  = "your-username"
git_email     = "your-email@example.com"
git_pat       = "ghp_..."

k3s_token             = "your-random-secure-token"
argocd_admin_password = "your-secure-password"
```

## Variable Reference

| Variable | Description | Stored in Vault |
|----------|-------------|-----------------|
| `tenancy_ocid` | OCI Tenancy OCID from the console | No |
| `user_ocid` | OCI User OCID for API access | No |
| `fingerprint` | API key fingerprint | No |
| `private_key_path` | Path to the OCI API private key | No |
| `compartment_ocid` | Compartment where resources will be created | No |
| `region` | OCI region identifier | No |
| `ssh_public_key_path` | Path to SSH public key in OpenSSH format | Yes |
| `cloudflare_api_token` | Cloudflare API token with Zone.DNS Edit | Yes |
| `cloudflare_zone_id` | Zone ID from Cloudflare dashboard | Yes |
| `domain_name` | Domain for the cluster applications | Yes |
| `acme_email` | Email for Let's Encrypt notifications | Yes |
| `git_repo_url` | HTTPS URL of your forked repository | Yes |
| `git_username` | GitHub username | Yes |
| `git_email` | Email for GHCR authentication | Yes |
| `git_pat` | GitHub Personal Access Token | Yes |
| `k3s_token` | Shared secret for K3s node authentication | Yes |
| `argocd_admin_password` | Password for ArgoCD admin user | Yes |

<Aside type="note">
  OCI authentication variables are not stored in Vault since they're needed to access Vault. Keep them in a password manager.
</Aside>

## SSH Key Format

The SSH public key must be in OpenSSH format, starting with `ssh-rsa` or `ssh-ed25519`. PEM format keys are not accepted by OCI metadata.

To generate a new key:

```bash
ssh-keygen -t ed25519 -f ./oci_key -N ""
```

## OCI Always Free Resources

After `terraform apply`, the following Always Free resources are created:

| Resource | Free Tier Limit | Usage |
|----------|-----------------|-------|
| Object Storage | 20 GB | ~1 MB (tfstate) |
| Vault Secrets | 150 | 10 secrets |
| Vault Master Keys | 20 versions | 1 key |
| Ampere A1 Compute | 4 OCPUs, 24 GB RAM | 4 OCPUs, 24 GB |

## Remote State

Terraform state is stored in OCI Object Storage bucket `k3s-tfstate` with versioning enabled. The bucket is created during the first apply and reused for subsequent runs.
