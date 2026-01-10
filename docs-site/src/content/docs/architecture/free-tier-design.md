---
title: Free Tier Design & Exposure
---

This guide explains how the cluster operates within the strict limits of Oracle Cloud's "Always Free" tier and how applications are exposed to the internet without a paid Load Balancer.

## 1. Staying "Always Free"

OCI provides a generous but strict set of free resources. This cluster uses the **Ampere A1 Compute** tier.

### Resource Limits & Allocation

| Resource | Limit | Cluster Usage | Breakdown |
| :--- | :--- | :--- | :--- |
| **OCPUs** | 4 OCPUs | **4 OCPUs** | 1 (Ingress) + 2 (Server) + 1 (Worker) |
| **Memory** | 24 GB | **24 GB** | 6GB (Ingress) + 12GB (Server) + 6GB (Worker) |
| **Storage** | 200 GB | **141 GB** | 3x 47GB Boot Volumes |
| **Load Balancer**| 1 (10Mbps) | **0** | We use a VM as a software Gateway instead. |
| **IPv4 Address** | Limited | **1** | Only the Ingress node has a Public IP. |

**Why no OCI Load Balancer?**
While OCI offers one free Load Balancer (10Mbps), it is bandwidth-constrained and adds complexity. Instead, we use the **Ingress Node** (`k3s-ingress`) as a dedicated entry point.

### Network Address Translation (NAT)

OCI's "NAT Gateway" service is **paid** (or consumes free credits). To stay strictly free, we implement **Software NAT** on the Ingress node.
- The `ingress` node forwards traffic from the private `server` and `worker` nodes to the internet.
- This is configured via `iptables` rules applied by `cloud-init` at boot.

## 2. Exposing Apps to the Internet

Since we don't use a Cloud Load Balancer service (Service Type: LoadBalancer), we expose traffic directly on the Ingress node's network interface.

### The `hostPort` Strategy

We run **Envoy Gateway** (the implementation of Kubernetes Gateway API) on the Ingress node.

1.  **Node Selector**: The Envoy Proxy pods are pinned to the `ingress` node using `nodeSelector: role=ingress`.
2.  **Host Port**: The Envoy container binds ports `80` and `443` directly to the host's network interface using the `hostPort` setting in the Pod spec.
    ```yaml
    ports:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
    ```
3.  **Traffic Flow**:
    `User` -> `Internet` -> `Ingress Node Public IP (80/443)` -> `Envoy Pod` -> `Pod Network (Flannel)` -> `App Pod (on any node)`

This setup mimics a "NodePort" but on a specific node and specific standard ports, effectively turning the Ingress node into a Load Balancer.

## 3. Example: Deploying a Public Nginx App

Let's deploy a simple Nginx server and expose it on `nginx.yourdomain.com`.

### Step 1: Define the App

Create a file `nginx-app.yaml` (or add to your gitops repo structure):

```yaml
# 1. The Workload
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-nginx
  template:
    metadata:
      labels:
        app: my-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
# 2. The Service
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  namespace: default
spec:
  selector:
    app: my-nginx
  ports:
  - port: 80
    targetPort: 80
```

### Step 2: Expose with Gateway API

Add an `HTTPRoute` to route traffic from the Gateway to your Service.

**Crucial**: You must add the `external-dns` annotation so Cloudflare knows where to point the domain.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-nginx-route
  namespace: default
  annotations:
    # REPLACE with your Ingress Node Public IP (from terraform output)
    external-dns.alpha.kubernetes.io/target: "132.226.43.62"
spec:
  parentRefs:
  - name: docs-gateway # Use the existing Gateway
  hostnames:
  - "nginx.k3s.sudhanva.me" # REPLACE with your domain
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-nginx
      port: 80
```

### Step 3: Secure with HTTPS

To enable automatic TLS, create a `Certificate` resource. Cert Manager (using HTTP-01 challenge) will verify your domain and store the secret.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-nginx-tls
  namespace: default
spec:
  secretName: my-nginx-tls
  issuerRef:
    name: cloudflare-issuer
    kind: ClusterIssuer
  commonName: "nginx.k3s.sudhanva.me"
  dnsNames:
  - "nginx.k3s.sudhanva.me"
```

*Note*: Update the `HTTPRoute` parent Gateway listener if needed, but usually the Gateway is configured to auto-discover certs or you attach the route to the HTTPS listener. (In our setup, the Gateway listeners are static, so you just need the cert secret to exist and be valid).

### Step 4: GitOps Sync

1.  Commit these files to your repository (e.g., `argocd/apps/nginx/`).
2.  Add an `Application` manifest for it in `argocd/applications.yaml`.
3.  Push to Git. Argo CD will sync, create the pods, External DNS will create the 'A' record pointing to your Ingress IP, and Cert Manager will issue the certificate.
