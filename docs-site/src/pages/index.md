---
layout: ../layouts/Layout.astro
title: K3s on Oracle Cloud Always Free
---

# K3s on OCI Always Free (The "Robust" Edition)

This project automates the deployment of a High Availability-ready Kubernetes cluster on Oracle Cloud Infrastructure's **Always Free** tier, solving specific challenges related to networking, ARM architecture, and GitOps bootstrapping.

## Architecture

### Compute (Ampere A1 Flex)
We utilize the generous Always Free ARM tier (4 OCPU, 24GB RAM total).
*   **Ingress Node** (`k3s-ingress`): 1 OCPU, 6GB RAM.
    *   **Role**: Entrypoint, NAT Gateway, Load Balancer.
    *   **Network**: Public Subnet (`10.0.1.0/24`). Has a Public IP.
*   **Server Node** (`k3s-server`): 2 OCPU, 12GB RAM.
    *   **Role**: Control Plane, Argo CD, System Services.
    *   **Network**: Private Subnet (`10.0.2.0/24`). No Public IP.
*   **Worker Node** (`k3s-worker`): 1 OCPU, 6GB RAM.
    *   **Role**: Workloads.
    *   **Network**: Private Subnet (`10.0.2.0/24`). No Public IP.

### Networking & NAT (The "Missing Link")
OCI's Always Free tier excludes Managed NAT Gateways. To allow private nodes to access the internet (required for installing K3s, pulling images), we turned the **Ingress Node** into a software Router/NAT.

**Configuration applied via `cloud-init`:**
1.  **IP Forwarding**: `sysctl -w net.ipv4.ip_forward=1`
2.  **Masquerading**: `iptables -t nat -A POSTROUTING -o enp0s6 -j MASQUERADE`
3.  **Firewall Fix**: Ubuntu's default firewall rules (`netfilter-persistent`) block forwarded traffic. We explicitly set:
    ```bash
    iptables -P FORWARD ACCEPT
    iptables -F FORWARD
    ```
    *Without this fix, the private nodes can reach the Ingress node but packets are dropped before exiting to the internet.*

## GitOps & CI/CD

### Argo CD Bootstrap
*   **Pattern**: App-of-Apps.
*   **Bootstrap**: Terraform generates an `argocd/` directory containing the Root App and all Infrastructure Apps (`cert-manager`, `external-dns`, `traefik`, `docs`).
*   **Sync**: The K3s Server node installs Argo CD on boot and applies the Root App manifest automatically.

### CI/CD Pipeline (GitHub Actions)
Since the cluster runs on **ARM64** (Ampere), we cannot use standard `amd64` Docker images.
*   **Workflow**: `.github/workflows/docker-publish.yml`
*   **Build**: Uses `docker/setup-qemu-action` and `docker/setup-buildx-action` to cross-compile for `linux/amd64` and `linux/arm64`.
*   **Registry**: Images are pushed to GitHub Container Registry (GHCR).
*   **Deployment**: Argo CD pulls the `latest` image from GHCR.

## Ingress & Gateway API
We use **Traefik** configured with Kubernetes Gateway API support.
*   **Strategy**: `hostNetwork: true` on the Ingress Node.
*   **Why**: OCI Load Balancers are paid (or limited). By running Traefik on the Ingress node's host network, ports 80/443 are exposed directly to the internet, bypassing the need for an external LB.
*   **DNS**: Cloudflare (managed by ExternalDNS).
*   **TLS**: Let's Encrypt (managed by Cert-Manager with Cloudflare DNS-01 solver).

## Verification

### 1. Check Connectivity
From your local machine, via the Ingress bastion:
```bash
# Check if Server node is ready
ssh -J ubuntu@<ingress-ip> ubuntu@10.0.2.10 "sudo kubectl get nodes"
```

### 2. Check GitOps Status
```bash
ssh -J ubuntu@<ingress-ip> ubuntu@10.0.2.10 "sudo kubectl get app -n argocd"
```

### 3. Build Status
Check GitHub Actions:
```bash
gh run list
```

## Troubleshooting Log
*   **Issue**: `curl: (6) Could not resolve host: get.k3s.io` on private nodes.
    *   **Root Cause**: Ingress node `FORWARD` chain policy was `DROP`.
    *   **Fix**: Added `iptables -P FORWARD ACCEPT` to `cloud-init`.
*   **Issue**: `exec format error` in pods.
    *   **Root Cause**: Deploying `amd64` images to `arm64` nodes.
    *   **Fix**: Updated GH Actions to build multi-arch images.