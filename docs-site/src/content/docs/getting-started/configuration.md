---
title: Configuration
---

Create `tf-k3s/terraform.tfvars` with your environment-specific values. Do not commit this file to version control.

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
git_pat       = "ghp_..."
```

## Variable Reference

| Variable | Description |
|----------|-------------|
| `tenancy_ocid` | OCI Tenancy OCID from the console |
| `user_ocid` | OCI User OCID for API access |
| `fingerprint` | API key fingerprint |
| `private_key_path` | Path to the OCI API private key |
| `compartment_ocid` | Compartment where resources will be created |
| `region` | OCI region identifier |
| `ssh_public_key_path` | Path to SSH public key in OpenSSH format |
| `cloudflare_api_token` | Cloudflare API token with Zone.DNS Edit |
| `cloudflare_zone_id` | Zone ID from Cloudflare dashboard |
| `domain_name` | Domain for the cluster applications |
| `acme_email` | Email for Let's Encrypt notifications |
| `git_repo_url` | HTTPS URL of your forked repository |
| `git_username` | GitHub username |
| `git_pat` | GitHub Personal Access Token |

## SSH Key Format

The SSH public key must be in OpenSSH format, starting with `ssh-rsa` or `ssh-ed25519`. PEM format keys are not accepted by OCI metadata.

To convert a PEM key:

```bash
ssh-keygen -y -f ~/.oci/oci_api_key.pem > ssh_key.pub
```
