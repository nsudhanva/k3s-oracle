# Fully Automated OCI Always Free K3s Cluster

This project sets up a High Availability (sort of) K3s cluster on Oracle Cloud Infrastructure (OCI) using **Always Free** resources (Ampere A1 Flex instances). It bootstraps Argo CD for GitOps and deploys a documentation application exposed via Kubernetes Gateway API (Envoy Gateway) with automatic HTTPS (Cert Manager + Cloudflare).

## Architecture

- **Infrastructure**: Terraform managed.
  - **Network**: VCN with Public and Private Subnets.
  - **Compute**: 3x VM.Standard.A1.Flex instances (ARM64).
    - `k3s-ingress` (1 OCPU, 6GB RAM): Public Subnet. Acts as NAT Gateway and Ingress Gateway. Static IP `10.0.1.10`.
    - `k3s-server` (2 OCPU, 12GB RAM): Private Subnet. Runs K3s Server and Argo CD. Static IP `10.0.2.10`.
    - `k3s-worker` (1 OCPU, 6GB RAM): Private Subnet. Runs K3s Agent.
- **Cluster**: K3s.
- **GitOps**: Argo CD bootstrapped automatically.
- **Ingress**: Envoy Gateway (via Gateway API) running on the Public Node (`hostPort: 80/443`).
- **DNS/TLS**: External DNS (Cloudflare) + Cert Manager (Let's Encrypt HTTP-01 via Gateway API).

## Prerequisites

1. **OCI Account**: Always Free eligible.
2. **Cloudflare Account**: Domain managed by Cloudflare + API Token (Edit Zone DNS capability).
3. **Git Repository**: A **private** repository (GitHub) to hold your GitOps manifests.
4. **Terraform**: Installed locally.

## Setup Instructions

### 1. Prepare Credentials

- Ensure you have your OCI API Key (`.pem`) and config details.
- Have your OCI SSH Public Key ready (e.g. `~/.oci/oci_api_key_public.pem`).
- Create a GitHub Personal Access Token (Classic) with `repo` and `read:packages` scopes.

### 2. Configure Terraform

Create a `terraform.tfvars` file in `tf-k3s/` directory with your details:

```hcl
tenancy_ocid         = "ocid1.tenancy.oc1..."
user_ocid            = "ocid1.user.oc1..."
fingerprint          = "xx:xx:xx..."
private_key_path     = "/path/to/oci_api_key.pem"
region               = "us-ashburn-1"
compartment_ocid     = "ocid1.compartment.oc1..."

ssh_public_key_path  = "/path/to/oci_api_key_public.pem" # Path to your OpenSSH formatted public key
cloudflare_api_token = "your-cloudflare-token"
cloudflare_zone_id   = "your-zone-id"
domain_name          = "k3s.example.com"
acme_email           = "you@example.com"

git_repo_url         = "https://github.com/your-user/your-repo.git"
git_pat              = "github_pat_..."
git_username         = "your-github-username"
```

### 3. Generate Manifests & Infrastructure

Run Terraform to create the infrastructure and generate the GitOps manifests locally.

```bash
cd tf-k3s
terraform init
terraform apply -auto-approve
```

This will:

1. Provision OCI Networking and Instances.
2. Generate Kubernetes manifests in `argocd/` directory.
3. Bootstrap K3s (wait a few minutes for cloud-init).

### 4. Push to Git (Crucial Step)

Terraform generates the specific manifests for your domain and environment. You MUST push them to your repository so Argo CD can see them.

```bash
cd .. # Back to repo root
git add argocd/
git commit -m "Configure cluster manifests"
git push
```

### 5. Verify Installation

Get the Kubeconfig command from Terraform outputs (or use the displayed SSH command):

```bash
terraform output kubeconfig_command
```

Check Argo CD status:

```bash
# Connect via Jump Host
ssh -J ubuntu@<ingress-ip> ubuntu@10.0.2.10 "sudo kubectl get applications -n argocd"
```

You should see `root-app` and child apps syncing. Note that `envoy-gateway` and `external-dns` might take a moment to stabilize.

### 6. Access Application

Visit `https://k3s.example.com` (your configured domain).
It should load the documentation site, secured with a valid Let's Encrypt certificate.

## Troubleshooting

See `docs-site/src/content/docs/troubleshooting.md` for detailed solutions to common issues like firewall blocks, SSH key formats, and OCI specific quirks.
