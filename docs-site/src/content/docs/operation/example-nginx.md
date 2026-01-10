---
title: Example - Deploy Nginx
---

This guide walks through deploying a public nginx application on the cluster.

```mermaid
flowchart TB
    subgraph Internet
        User((User))
        CF[Cloudflare DNS]
    end

    subgraph Cluster["K3s Cluster"]
        GW[public-gateway<br/>:443]
        Route[nginx-route]
        Svc[nginx Service]
        Pod[nginx Pod]
    end

    User -->|https://nginx.example.com| CF
    CF -->|A Record| GW
    GW --> Route
    Route --> Svc
    Svc --> Pod
```

## Overview

You will:

1. Create Kubernetes manifests for nginx
2. Register the application with Argo CD
3. Configure DNS and TLS
4. Verify the deployment

```mermaid
flowchart LR
    subgraph Step1["Step 1"]
        D[deployment.yaml]
        S[service.yaml]
    end

    subgraph Step2["Step 2"]
        GW[Update Gateway]
        HR[httproute.yaml]
        Cert[certificate.yaml]
    end

    subgraph Step3["Step 3"]
        App[applications.yaml]
    end

    subgraph Step4["Step 4"]
        Push[git push]
        Verify[curl https://...]
    end

    Step1 --> Step2 --> Step3 --> Step4
```

## Create Application Directory

Create the directory structure:

```bash
mkdir -p argocd/apps/nginx
```

## Deployment Manifest

Create `argocd/apps/nginx/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
```

The `nginx:alpine` image supports ARM64.

## Service Manifest

Create `argocd/apps/nginx/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

## Update Public Gateway

Add a new HTTPS listener for nginx to `argocd/apps/docs/gateway.yaml`:

```yaml
- name: https-nginx
  port: 443
  protocol: HTTPS
  hostname: "nginx.example.com"
  allowedRoutes:
    namespaces:
      from: All
  tls:
    mode: Terminate
    certificateRefs:
    - name: nginx-tls
```

All applications share the single `public-gateway` since only one Envoy can bind to hostPort 80/443.

## HTTPRoute Manifests

Create `argocd/apps/nginx/httproute.yaml` with both HTTPS route and HTTP redirect:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx-route
  namespace: default
  annotations:
    external-dns.alpha.kubernetes.io/target: "<ingress-public-ip>"
spec:
  parentRefs:
  - name: public-gateway
    sectionName: https-nginx
  hostnames:
  - "nginx.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: nginx
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx-redirect
  namespace: default
spec:
  parentRefs:
  - name: public-gateway
    sectionName: http
  hostnames:
  - "nginx.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
```

Replace `<ingress-public-ip>` with your ingress node's public IP from `terraform output`.

Replace `nginx.example.com` with your desired subdomain.

## TLS Certificate

Create `argocd/apps/nginx/certificate.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx-tls
  namespace: default
spec:
  secretName: nginx-tls
  issuerRef:
    name: cloudflare-issuer
    kind: ClusterIssuer
  dnsNames:
  - "nginx.example.com"
```

## Register with Argo CD

Add the application to `argocd/applications.yaml`:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-username/k3s-oracle.git
    targetRevision: HEAD
    path: argocd/apps/nginx
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Replace the `repoURL` with your repository URL.

## Deploy

Commit and push the changes:

```bash
git add argocd/apps/nginx argocd/applications.yaml
git commit -m "Add nginx application"
git push
```

Argo CD will automatically sync the application.

## Verify

### Check Application Status

```bash
kubectl get applications -n argocd
```

The `nginx-app` should show `Synced` and `Healthy`.

### Check Pods

```bash
kubectl get pods -l app=nginx
```

### Check Certificate

```bash
kubectl get certificate nginx-tls
```

The certificate should show `Ready: True` after a few minutes.

### Test Access

```bash
curl -I https://nginx.example.com
```

You should receive a 200 response with the nginx welcome page.

## Complete File Structure

```text
argocd/apps/nginx/
├── deployment.yaml
├── service.yaml
├── httproute.yaml
└── certificate.yaml
```

## Cleanup

To remove the application:

1. Delete the application block from `argocd/applications.yaml`
2. Delete the `argocd/apps/nginx` directory
3. Commit and push

Argo CD will remove all resources automatically due to the finalizer.
