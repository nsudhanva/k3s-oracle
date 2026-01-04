---
layout: ../layouts/Layout.astro
title: K3s on Oracle Cloud Always Free
---

# Project Documentation

## Architecture

This cluster runs on **Oracle Cloud Infrastructure (OCI)** using **Always Free** resources.

### Hardware (Ampere A1 Flex)
*   **Ingress Node**: 1 OCPU, 6GB RAM (Public Subnet)
*   **Server Node**: 2 OCPU, 12GB RAM (Private Subnet)
*   **Worker Node**: 1 OCPU, 6GB RAM (Private Subnet)

### Networking
*   **VCN**: `10.0.0.0/16`
*   **Public Subnet**: `10.0.1.0/24` (Contains Ingress Node)
*   **Private Subnet**: `10.0.2.0/24` (Contains Server & Worker)
*   **NAT**: The Ingress Node acts as a software NAT Gateway for the private nodes using `iptables`.

### Kubernetes & GitOps
*   **Distro**: K3s
*   **GitOps**: Argo CD (App of Apps pattern)
*   **Ingress**: Traefik (via Kubernetes Gateway API) running with `hostNetwork: true` on the Ingress node.
*   **DNS/TLS**: ExternalDNS (Cloudflare) + Cert Manager (Let's Encrypt).

## Lessons Learned & Fixes

### 1. NAT Routing on OCI
By default, standard Linux instances don't forward traffic. The private nodes couldn't access the internet (needed for K3s installation).
**Fix**: Enabled `net.ipv4.ip_forward=1` and set up `iptables -t nat -A POSTROUTING -o enp0s6 -j MASQUERADE` on the Ingress node.

### 2. OCI Firewall (Security Lists vs iptables)
OCI Security Lists allow traffic at the network edge, but Ubuntu's internal `iptables` (via `netfilter-persistent`) was blocking forwarded traffic by default with a `REJECT` rule in the `FORWARD` chain.
**Fix**: Flushed `FORWARD` chain and set policy to `ACCEPT`.
```bash
iptables -P FORWARD ACCEPT
iptables -F FORWARD
netfilter-persistent save
```

### 3. ARM64 Compatibility
All images deployed to this cluster must be built for `linux/arm64`. Standard `amd64` images will crash with `exec format error`.
**Solution**: Use Docker Buildx with QEMU in GitHub Actions to cross-compile images.

### 4. K3s & Gateway API
K3s comes with Traefik by default, but we disabled it to manage it explicitly via GitOps. We then installed Traefik via Helm, configured to support the Gateway API `v1`.

## Deployment Pipeline
This documentation site is built with **Astro**, containerized, and pushed to **GitHub Container Registry (GHCR)** via GitHub Actions. Argo CD watches the repo and pulls the new image automatically.
