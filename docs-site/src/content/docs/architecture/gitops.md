---
title: GitOps
---

Argo CD manages all cluster resources using the App-of-Apps pattern.

```mermaid
flowchart TB
    subgraph GitHub["GitHub Repository"]
        Repo[(k3s-oracle)]
        AppYAML[applications.yaml]
        Infra[infrastructure/]
        Apps[apps/]
    end

    subgraph ArgoCD["Argo CD"]
        Root[Root Application<br/>argocd-root]
        AppController[Application Controller]
    end

    subgraph Cluster["K3s Cluster"]
        CRDs[Gateway API CRDs]
        CM[Cert Manager]
        EG[Envoy Gateway]
        ED[External DNS]
        ArgoSelf[Argo CD]
        DocsApp[Docs App]
    end

    Repo --> Root
    Root -->|reads| AppYAML
    AppYAML --> AppController
    AppController -->|syncs| Infra
    AppController -->|syncs| Apps
    Infra --> CRDs
    Infra --> CM
    Infra --> EG
    Infra --> ED
    Infra --> ArgoSelf
    Apps --> DocsApp
```

## Directory Structure

```text
argocd/
├── kustomization.yaml
├── applications.yaml
├── infrastructure/
│   ├── argocd/
│   ├── argocd-ingress/
│   ├── cert-manager/
│   ├── envoy-gateway/
│   └── external-dns/
└── apps/
    └── docs/
```

```mermaid
flowchart LR
    subgraph Root["Root Application"]
        KustomYAML[kustomization.yaml]
        AppsYAML[applications.yaml]
    end

    subgraph Infrastructure
        ArgoCD[argocd/]
        ArgoIngress[argocd-ingress/]
        CertMgr[cert-manager/]
        Envoy[envoy-gateway/]
        ExtDNS[external-dns/]
    end

    subgraph UserApps["User Applications"]
        Docs[docs/]
    end

    KustomYAML --> AppsYAML
    AppsYAML --> ArgoCD
    AppsYAML --> ArgoIngress
    AppsYAML --> CertMgr
    AppsYAML --> Envoy
    AppsYAML --> ExtDNS
    AppsYAML --> Docs
```

## Applications

| Application | Purpose | Namespace |
|-------------|---------|-----------|
| gateway-api-crds | Gateway API CRDs | cluster-wide |
| cert-manager | TLS certificate automation | cert-manager |
| external-dns | Cloudflare DNS management | external-dns |
| envoy-gateway | Gateway API controller | envoy-gateway-system |
| argocd-self-managed | Self-managed Argo CD | argocd |
| argocd-ingress | Argo CD UI ingress | argocd |
| docs-app | Documentation website | default |

## Secrets

Cloudflare API tokens are injected during cluster bootstrap via cloud-init and stored in the `cert-manager` and `external-dns` namespaces.

```mermaid
sequenceDiagram
    participant TF as Terraform
    participant CI as Cloud-Init
    participant K3s as K3s Server
    participant Argo as Argo CD

    TF->>CI: Pass secrets via cloud-init
    CI->>K3s: Create Kubernetes Secrets
    Note over K3s: cloudflare-api-token<br/>in cert-manager & external-dns
    K3s->>Argo: Secrets available
    Argo->>Argo: Deploy apps with secrets
```

## Sync Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant Argo as Argo CD
    participant K8s as K3s Cluster

    Dev->>GH: git push
    Note over Argo: Polling (3 min) or Webhook
    Argo->>GH: Fetch latest manifests
    Argo->>Argo: Compare desired vs actual
    alt OutOfSync
        Argo->>K8s: Apply changes
        K8s->>Argo: Status update
        Argo->>Argo: Mark Synced
    else Synced
        Note over Argo: No action needed
    end
```

## Sync Issues

If an application remains OutOfSync or Unknown:

### CRD Dependencies

Some applications depend on CRDs that must be installed first. The `gateway-api-crds` application installs before `envoy-gateway`.

```mermaid
flowchart LR
    subgraph Phase1["Phase 1"]
        CRDs[gateway-api-crds]
    end

    subgraph Phase2["Phase 2"]
        CM[cert-manager]
        ED[external-dns]
    end

    subgraph Phase3["Phase 3"]
        EG[envoy-gateway]
        Argo[argocd]
    end

    subgraph Phase4["Phase 4"]
        Ingress[argocd-ingress]
        Docs[docs-app]
    end

    CRDs --> CM
    CRDs --> ED
    CM --> EG
    ED --> EG
    EG --> Ingress
    EG --> Docs
    Argo --> Ingress
```

### Hard Refresh

Force a sync with:

```bash
kubectl patch app <app-name> -n argocd --type merge \
  -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
```
