# K3s on Oracle Cloud Always Free

A production-ready K3s cluster on Oracle Cloud Infrastructure using Always Free tier resources. This project provisions infrastructure with Terraform, bootstraps Argo CD for GitOps, and deploys applications via Gateway API with automatic HTTPS.

```mermaid
graph TB
    subgraph Internet
        User((User))
        CF[Cloudflare DNS]
    end

    subgraph OCI["Oracle Cloud (Always Free)"]
        subgraph Public["Public Subnet"]
            Ingress[k3s-ingress<br/>NAT + Envoy]
        end
        subgraph Private["Private Subnet"]
            Server[k3s-server<br/>Control Plane]
            Worker[k3s-worker<br/>Workloads]
        end
    end

    subgraph GitHub
        Repo[(Repository)]
    end

    User -->|HTTPS| CF
    CF --> Ingress
    Ingress --> Server
    Ingress --> Worker
    Repo -->|GitOps| Server
```

## Architecture

The cluster runs on three Ampere A1 ARM64 instances within OCI's Always Free limits (4 OCPUs, 24GB RAM total):

| Node | Resources | Subnet | Role |
|------|-----------|--------|------|
| k3s-ingress | 1 OCPU, 6GB | Public (10.0.1.0/24) | NAT gateway, Envoy Gateway |
| k3s-server | 2 OCPU, 12GB | Private (10.0.2.0/24) | K3s control plane, Argo CD |
| k3s-worker | 1 OCPU, 6GB | Private (10.0.2.0/24) | Application workloads |

## Components

| Component | Purpose |
|-----------|---------|
| K3s | Lightweight Kubernetes distribution |
| Argo CD | GitOps continuous delivery |
| Envoy Gateway | Gateway API implementation |
| External DNS | Automatic Cloudflare DNS updates |
| Cert Manager | Let's Encrypt certificate automation |

```mermaid
flowchart LR
    subgraph Infra["Infrastructure"]
        TF[Terraform]
    end

    subgraph Cluster["K3s Cluster"]
        Argo[Argo CD]
        EG[Envoy Gateway]
        CM[Cert Manager]
        ED[External DNS]
    end

    subgraph External["External Services"]
        OCI[(OCI)]
        GH[(GitHub)]
        CFl[(Cloudflare)]
        LE[(Let's Encrypt)]
    end

    TF -->|provisions| OCI
    TF -->|generates| GH
    GH -->|syncs| Argo
    Argo -->|deploys| EG
    Argo -->|deploys| CM
    Argo -->|deploys| ED
    CM -->|certificates| LE
    ED -->|DNS records| CFl
```

## Prerequisites

- OCI Account with Always Free eligibility
- Cloudflare account with a managed domain
- GitHub account with a Personal Access Token
- Terraform installed locally

## Quick Start

### Create Configuration

Create `tf-k3s/terraform.tfvars`:

```hcl
tenancy_ocid         = "ocid1.tenancy.oc1..."
user_ocid            = "ocid1.user.oc1..."
fingerprint          = "xx:xx:xx..."
private_key_path     = "/path/to/oci_api_key.pem"
region               = "us-ashburn-1"
compartment_ocid     = "ocid1.compartment.oc1..."

ssh_public_key_path  = "/path/to/ssh_key.pub"
cloudflare_api_token = "your-cloudflare-token"
cloudflare_zone_id   = "your-zone-id"
domain_name          = "k3s.example.com"
acme_email           = "admin@example.com"

git_repo_url         = "https://github.com/your-user/k3s-oracle.git"
git_pat              = "ghp_..."
git_username         = "your-github-username"
```

### Deploy

```bash
cd tf-k3s
terraform init
terraform apply
```

### Push Manifests

Terraform generates GitOps manifests that must be committed:

```bash
git add argocd/
git commit -m "Configure cluster manifests"
git push
```

### Verify

Wait approximately five minutes for bootstrapping, then verify:

```bash
ssh -J ubuntu@<ingress-ip> ubuntu@10.0.2.10 "sudo kubectl get applications -n argocd"
```

## Documentation

The full documentation is available at the live cluster site: **[https://k3s.sudhanva.me](https://k3s.sudhanva.me)**.

To view and edit the documentation locally:
```bash
cd docs-site
bun install
bun start
```

## License

MIT
