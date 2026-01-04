---
title: GitOps & Argo CD
---

# GitOps with Argo CD

Everything in this cluster is managed via Argo CD following the **App-of-Apps** pattern.

## Directory Structure

- `argocd/applications.yaml`: The Root App definition. It points to the `argocd/` directory.
- `argocd/infrastructure/`: Low-level system services.
  - `cert-manager`
  - `external-dns`
  - `traefik`
  - `argocd-ingress` (Exposes Argo CD itself)
- `argocd/apps/`: Your business workloads (e.g., `docs-app`).

## Secrets Management

We use standard Kubernetes Secrets for simplicity in this "Always Free" demo.

- Cloudflare API tokens are passed via Terraform to the K3s server manifests on boot.
- These are stored in the `cert-manager` and `external-dns` namespaces.

## Handling Sync Issues

If an app stays in `OutOfSync` or `Unknown`:

1. Check CRDs: Some apps depend on CRDs (like Gateway API) that must be installed first.
2. Hard Refresh:

   ```bash
   kubectl patch app <app-name> -n argocd --type merge -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
   ```
