# Fully Automated OCI Always Free K3s Cluster

This project sets up a High Availability (sort of) K3s cluster on Oracle Cloud Infrastructure (OCI) using **Always Free** resources (Ampere A1 Flex instances). It bootstraps Argo CD for GitOps and deploys an Nginx application exposed via Kubernetes Gateway API (Traefik) with automatic HTTPS (Cert Manager + Cloudflare).

## Architecture

- **Infrastructure**: Terraform managed.
  - **Network**: VCN with Public and Private Subnets.
  - **Compute**: 3x VM.Standard.A1.Flex instances (ARM64).
    - `k3s-ingress` (1 OCPU, 6GB RAM): Public Subnet. Acts as NAT Gateway and Ingress Gateway. Static IP `10.0.1.10`.
    - `k3s-server` (2 OCPU, 12GB RAM): Private Subnet. Runs K3s Server and Argo CD. Static IP `10.0.2.10`.
    - `k3s-worker` (1 OCPU, 6GB RAM): Private Subnet. Runs K3s Agent.
- **Cluster**: K3s.
- **GitOps**: Argo CD bootstrapped automatically.
- **Ingress**: Traefik (via Gateway API) running on the Public Node (`hostNetwork: true`).
- **DNS/TLS**: External DNS (Cloudflare) + Cert Manager (Let's Encrypt DNS-01 via Cloudflare).

## Prerequisites

1. **OCI Account**: Always Free eligible.
2. **Cloudflare Account**: Domain managed by Cloudflare + API Token (Edit Zone DNS capability).
3. **Git Repository**: A repository (GitHub/GitLab/etc) to hold your GitOps manifests.
4. **Terraform**: Installed locally.

## Setup Instructions

### 1. Prepare Credentials
- Ensure you have your OCI API Key (`.pem`) and config details.
- Generate or have an SSH Public Key ready.

### 2. Configure Terraform
Create a `terraform.tfvars` file in `tf-k3s/` directory with your details:

```hcl
tenancy_ocid         = "ocid1.tenancy.oc1..."
user_ocid            = "ocid1.user.oc1..."
fingerprint          = "xx:xx:xx..."
private_key_path     = "/path/to/oci_api_key.pem"
region               = "us-ashburn-1"
compartment_ocid     = "ocid1.compartment.oc1..."

my_ssh_public_key    = "ssh-rsa AAAA..." # Optional, will generate if empty
cloudflare_api_token = "your-cloudflare-token"
cloudflare_zone_id   = "your-zone-id"
domain_name          = "k3s.example.com"
acme_email           = "you@example.com"

git_repo_url         = "https://github.com/your-user/your-repo.git"
```

### 3. Generate Manifests & Infrastructure
Run Terraform to create the infrastructure and generate the GitOps manifests locally.

```bash
cd tf-k3s
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This will:
1. Provision OCI Networking and Instances.
2. Generate Kubernetes manifests in `../gitops-repo/`.
3. Bootstrap K3s (wait a few minutes for cloud-init).

### 4. Push to Git (Crucial Step)
The cluster is bootstrapped to look at your Git repository, but the repository is empty! You must push the generated manifests.

```bash
# Clone your repo (if not already)
git clone https://github.com/your-user/your-repo.git my-repo
cd my-repo

# Copy the generated manifests
1. Copy the generated files from 'argocd/' to your Git repository: ${var.git_repo_url}
2. Push the changes to the repository.
3. Wait for the instances to provision and K3s to install.
4. Verify Argo CD status:
   ssh -J ubuntu@${oci_core_instance.ingress.public_ip} ubuntu@10.0.2.10 "sudo kubectl get applications -n argocd"

# Commit and Push
git add .
git commit -m "Initial GitOps Bootstrap"
git push origin main
```

### 5. Verify Installation
Get the Kubeconfig command from Terraform outputs:

```bash
# In tf-k3s/ directory
terraform output kubeconfig_command
```
Run the output command to fetch `k3s.yaml` to your local machine (or just run the SSH command to view it).

Check Nodes:
```bash
export KUBECONFIG=./k3s.yaml
kubectl get nodes -o wide
```
You should see 3 nodes (ingress, server, worker).

Check Argo CD:
```bash
kubectl get applications -n argocd
```
You should see `root-app` and the child apps (`cert-manager`, `traefik`, `nginx-app`, etc.) syncing.

### 6. Access Application
Visit `https://k3s.example.com` (your configured domain).
It should load the Nginx welcome page, secured with a valid Let's Encrypt certificate.

## Troubleshooting

- **OCI Out of Capacity**: A1 instances are popular. If Terraform fails with "Out of Capacity", try a different Availability Domain (modify `compute.tf` to pick specific AD) or wait/retry.
- **Argo CD Not Syncing**: Check `kubectl get app -n argocd`. If `Unknown`, check logs of argocd-server. Ensure your Git Repo URL is correct and public (or you added credentials manually to Argo).
- **Gateway Not Routing**: Ensure Traefik pod is running on `k3s-ingress` node (`kubectl get pods -n kube-system -o wide`). Check if port 80/443 are open in Security List (Terraform handles this).
- **Cert Manager Failures**: Check `kubectl get chall -A`. If DNS01 challenge fails, verify Cloudflare Token permissions.

## Security Note
- The Ingress Node is the ONLY node with a Public IP.
- Server and Worker are in a Private Subnet, accessing internet via Ingress Node (NAT).
- K3s API is accessible internally. To access remotely, you might need to SSH Tunnel via the Ingress Node (Output `kubeconfig_command` uses SSH tunnel implicitly? No, you might need to setup a tunnel).
- **Tip**: Use `ssh -L 6443:10.0.2.10:6443 ubuntu@<public-ip>` to expose K3s API locally.