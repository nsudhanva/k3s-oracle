---
title: Ingress Without Load Balancer
---

This cluster exposes applications to the internet without using a cloud load balancer.

## Traditional Cloud Setup

In a typical cloud Kubernetes deployment:

```mermaid
flowchart LR
    User((User)) --> LB[Cloud Load Balancer<br/>$$$/month]
    LB --> NP[NodePort Service<br/>:30000-32767]
    NP --> Pod[Application Pod]
```

1. A cloud load balancer receives traffic on ports 80/443
2. The load balancer forwards traffic to NodePort services
3. Kubernetes routes traffic to the appropriate pods

This requires a paid load balancer resource.

## This Cluster's Approach

This cluster binds the ingress controller directly to the host network interface:

```mermaid
flowchart LR
    User((User)) --> DNS[Cloudflare DNS]
    DNS --> Ingress[Ingress Node<br/>hostPort :80/:443]
    Ingress --> Envoy[Envoy Pod]
    Envoy --> Pod[Application Pod]

    style Ingress fill:#90EE90
    style DNS fill:#87CEEB
```

1. DNS points directly to the ingress node's public IP
2. Envoy Gateway binds ports 80/443 on the host
3. Envoy routes traffic to backend services

No load balancer is involved.

## How It Works

### DNS Configuration

External DNS creates A records in Cloudflare pointing your domain to the ingress node's public IP:

```text
k3s.example.com -> 132.226.43.62
```

### hostPort Binding

The Envoy proxy runs as a Kubernetes pod but binds directly to the host's network ports using hostPort:

```yaml
containers:
  - name: envoy
    ports:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
```

When traffic arrives at the ingress node on port 80 or 443, it goes directly to the Envoy container.

### Node Selector

The Envoy proxy only runs on the ingress node via nodeSelector:

```yaml
nodeSelector:
  role: ingress
```

The ingress node is labeled during K3s installation with `--node-label role=ingress`.

### Traffic Flow

```mermaid
flowchart TB
    subgraph Internet
        User((User))
        DNS[DNS: k3s.example.com<br/>→ 132.226.43.62]
    end

    subgraph Ingress["Ingress Node (132.226.43.62)"]
        HP[hostPort :443]
        Envoy[Envoy Container]
    end

    subgraph Cluster["K3s Cluster Network"]
        GW[Gateway API<br/>public-gateway]
        HR[HTTPRoute]
        SVC[Backend Service<br/>ClusterIP]
        Pod[Application Pod]
    end

    User -->|HTTPS| DNS
    DNS -->|TCP :443| HP
    HP --> Envoy
    Envoy --> GW
    GW --> HR
    HR --> SVC
    SVC --> Pod
```

## Why hostPort Instead of hostNetwork

```mermaid
flowchart TB
    subgraph HostNetwork["hostNetwork: true ❌"]
        HN_Pod[Pod]
        HN_Host[Host Network Namespace]
        HN_DNS[/etc/resolv.conf<br/>Host DNS]
        HN_Pod --> HN_Host
        HN_Host --> HN_DNS
        HN_DNS -.->|Cannot resolve| K8S_SVC[kubernetes.default]
    end

    subgraph HostPort["hostPort ✓"]
        HP_Pod[Pod]
        HP_Cluster[Cluster Network Namespace]
        HP_CoreDNS[CoreDNS]
        HP_Ports[Host Ports :80/:443]
        HP_Pod --> HP_Cluster
        HP_Cluster --> HP_CoreDNS
        HP_Pod -.-> HP_Ports
        HP_CoreDNS -->|Resolves| K8S_SVC2[kubernetes.default]
    end
```

Using `hostNetwork: true` would give the pod the host's network namespace. This causes DNS resolution issues because the host's `/etc/resolv.conf` does not know about Kubernetes services.

Using `hostPort` keeps the pod in the cluster network namespace while still binding to host ports. The pod can resolve Kubernetes services via CoreDNS.

## Single Public Gateway

All public applications share a single Gateway resource (`public-gateway` in the `default` namespace). This is required because only one Envoy deployment can bind to hostPort 80/443 on the ingress node.

The Gateway defines multiple HTTPS listeners, one per hostname:

```yaml
listeners:
- name: http
  port: 80
  protocol: HTTP
  allowedRoutes:
    namespaces:
      from: All
- name: https-docs
  port: 443
  protocol: HTTPS
  hostname: "k3s.sudhanva.me"
  tls:
    certificateRefs:
    - name: docs-tls
- name: https-argocd
  port: 443
  protocol: HTTPS
  hostname: "cd.k3s.sudhanva.me"
  tls:
    certificateRefs:
    - name: argocd-tls
      namespace: argocd
```

## HTTPS Enforcement

All HTTP traffic is redirected to HTTPS using a 301 permanent redirect. Each application has two HTTPRoutes:

```mermaid
flowchart LR
    subgraph Request["User Request"]
        HTTP[HTTP :80]
        HTTPS[HTTPS :443]
    end

    subgraph Gateway["public-gateway"]
        L80[http listener]
        L443[https-* listener]
    end

    subgraph Routes["HTTPRoutes"]
        Redirect[docs-redirect<br/>301 → HTTPS]
        Main[docs-route<br/>Backend Service]
    end

    HTTP --> L80
    L80 --> Redirect
    Redirect -->|301 Redirect| HTTPS
    HTTPS --> L443
    L443 --> Main
    Main --> App[Application]
```

1. A route attached to the HTTPS listener that serves traffic
2. A redirect route attached to the HTTP listener

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: docs-redirect
spec:
  parentRefs:
  - name: public-gateway
    sectionName: http
  hostnames:
  - "k3s.sudhanva.me"
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
```

## Cross-Namespace References

When the Gateway references a TLS secret in a different namespace, a ReferenceGrant is required:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-argocd-tls
  namespace: argocd
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: default
  to:
  - group: ""
    kind: Secret
    name: argocd-tls
```

This allows the public-gateway in the default namespace to use the argocd-tls secret.

## Security Considerations

### Single Point of Entry

All traffic enters through one node. If this node fails, the cluster is unreachable. For production workloads, consider:

- Multiple ingress nodes with round-robin DNS
- A cloud load balancer (not free)

### Firewall Rules

OCI security lists must allow inbound traffic on ports 80 and 443 from 0.0.0.0/0. The ingress node's iptables must also accept this traffic.

### TLS Termination

Envoy terminates TLS using certificates issued by Cert Manager. Traffic between Envoy and backend services is unencrypted within the cluster network.

## Comparison

| Approach | Cost | Complexity | Availability |
|----------|------|------------|--------------|
| Cloud Load Balancer | Paid | Low | High |
| hostPort (this cluster) | Free | Medium | Single node |
| NodePort + DNS | Free | Low | Single node |

This cluster uses hostPort for the balance of simplicity and Gateway API compatibility.
