---
title: Architecture Overview
---

This cluster runs on Oracle Cloud Infrastructure's Always Free tier using three Ampere A1 ARM64 instances.

```mermaid
graph TB
    subgraph Internet
        User((User))
        DNS[Cloudflare DNS]
    end

    subgraph OCI["Oracle Cloud Infrastructure"]
        subgraph Public["Public Subnet (10.0.1.0/24)"]
            Ingress[k3s-ingress<br/>1 OCPU, 6GB<br/>NAT + Envoy]
        end

        subgraph Private["Private Subnet (10.0.2.0/24)"]
            Server[k3s-server<br/>2 OCPU, 12GB<br/>Control Plane]
            Worker[k3s-worker<br/>1 OCPU, 6GB<br/>Workloads]
        end
    end

    User -->|HTTPS| DNS
    DNS -->|A Record| Ingress
    Ingress -->|hostPort 443| Server
    Ingress -->|hostPort 443| Worker
    Server <-->|K3s| Worker
    Private -->|NAT via iptables| Ingress
    Ingress -->|Internet Gateway| Internet
```

## Node Topology

| Node | OCPUs | RAM | Subnet | Purpose |
|------|-------|-----|--------|---------|
| k3s-ingress | 1 | 6GB | Public (10.0.1.0/24) | NAT gateway, ingress controller |
| k3s-server | 2 | 12GB | Private (10.0.2.0/24) | K3s control plane |
| k3s-worker | 1 | 6GB | Private (10.0.2.0/24) | Application workloads |

## Infrastructure

Terraform provisions the OCI environment in `tf-k3s/`.

### Network

- VCN CIDR: 10.0.0.0/16
- Public subnet: 10.0.1.0/24
- Private subnet: 10.0.2.0/24
- Internet gateway for public subnet
- Route table directing private subnet traffic through ingress node

### Security Lists

- Ingress ports 80 and 443 from 0.0.0.0/0
- NodePort range 30000-32767
- Full VCN internal communication

## Bootstrapping

Cloud-init scripts configure each node automatically.

```mermaid
sequenceDiagram
    participant TF as Terraform
    participant OCI as OCI API
    participant Server as k3s-server
    participant Ingress as k3s-ingress
    participant Worker as k3s-worker
    participant Argo as Argo CD
    participant GH as GitHub

    TF->>OCI: Create VCN, Subnets, Security Lists
    TF->>OCI: Create Instances with cloud-init

    par Server Bootstrap
        Server->>Server: Install K3s server
        Server->>Server: Deploy Argo CD HelmChart
        Server->>Server: Create secrets (Cloudflare, GitHub)
        Server->>Server: Create root Application
    and Ingress Bootstrap
        Ingress->>Ingress: Enable IP forwarding
        Ingress->>Ingress: Configure iptables NAT
        Ingress->>Server: Join cluster as agent
    and Worker Bootstrap
        Worker->>Server: Join cluster as agent
    end

    Argo->>GH: Fetch manifests
    Argo->>Server: Deploy applications
    Note over Argo,Server: Continuous sync loop
```

### Ingress Node

Defined in `cloud-init/ingress.yaml`:

- Enables IP forwarding
- Configures iptables masquerade for NAT
- Installs K3s agent with `role=ingress` label

### Server Node

Defined in `cloud-init/server.yaml`:

- Installs K3s server with Traefik disabled
- Deploys Argo CD via HelmChart manifest
- Creates secrets for Cloudflare, GitHub, and registry credentials
- Configures root Application for GitOps

### Worker Node

Defined in `cloud-init/worker.yaml`:

- Installs K3s agent
- Joins cluster using K3s token

## GitOps

Argo CD manages all cluster resources using the App-of-Apps pattern.

```mermaid
flowchart LR
    subgraph GitHub
        Repo[(k3s-oracle<br/>Repository)]
    end

    subgraph Cluster["K3s Cluster"]
        subgraph ArgoCD["Argo CD"]
            Root[Root App]
            Apps[Application<br/>Manifests]
        end

        subgraph Infra["Infrastructure Apps"]
            CRDs[Gateway API CRDs]
            CM[Cert Manager]
            EG[Envoy Gateway]
            ED[External DNS]
        end

        subgraph UserApps["User Applications"]
            Docs[Docs Site]
            ArgoUI[Argo CD UI]
        end
    end

    Repo -->|sync| Root
    Root -->|manages| Apps
    Apps -->|deploys| CRDs
    Apps -->|deploys| CM
    Apps -->|deploys| EG
    Apps -->|deploys| ED
    Apps -->|deploys| Docs
    Apps -->|deploys| ArgoUI
```

### Applications

| Application | Purpose |
|-------------|---------|
| gateway-api-crds | Gateway API CRDs |
| cert-manager | TLS certificate automation |
| external-dns | Cloudflare DNS management |
| external-secrets | OCI Vault integration |
| managed-secrets | Vault secret sync configuration |
| envoy-gateway | Gateway API implementation |
| argocd-self-managed | Self-managed Argo CD |
| argocd-ingress | Argo CD UI ingress |
| docs-app | Documentation website |

## Ingress

Envoy Gateway implements the Kubernetes Gateway API. The proxy binds to ports 80 and 443 on the ingress node using hostPort, allowing external traffic while maintaining cluster network connectivity for DNS resolution.

```mermaid
flowchart LR
    subgraph Internet
        Browser((Browser))
    end

    subgraph Ingress["Ingress Node"]
        HP80[hostPort :80]
        HP443[hostPort :443]
        Envoy[Envoy Proxy]
    end

    subgraph Cluster["K3s Cluster"]
        GW[public-gateway]
        HR1[HTTPRoute<br/>docs]
        HR2[HTTPRoute<br/>argocd]
        SVC1[docs Service]
        SVC2[argocd Service]
        POD1[docs Pod]
        POD2[argocd Pod]
    end

    Browser -->|HTTP| HP80
    Browser -->|HTTPS| HP443
    HP80 --> Envoy
    HP443 --> Envoy
    Envoy --> GW
    GW --> HR1
    GW --> HR2
    HR1 --> SVC1
    HR2 --> SVC2
    SVC1 --> POD1
    SVC2 --> POD2
```

## TLS Certificates

Cert Manager issues Let's Encrypt certificates using HTTP-01 challenges via Gateway API. External DNS updates Cloudflare A records to point to the ingress node public IP.

```mermaid
sequenceDiagram
    participant CM as Cert Manager
    participant LE as Let's Encrypt
    participant GW as Gateway
    participant CF as Cloudflare
    participant ED as External DNS

    ED->>CF: Create A record (domain → ingress IP)
    CM->>LE: Request certificate
    LE->>GW: HTTP-01 challenge request
    GW->>CM: Serve challenge token
    LE->>CM: Certificate issued
    CM->>GW: Store TLS secret
    Note over GW: HTTPS enabled
```
