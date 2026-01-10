---
title: Ingress Without Load Balancer
---

This cluster exposes applications to the internet without using a cloud load balancer.

## Traditional Cloud Setup

In a typical cloud Kubernetes deployment:

1. A cloud load balancer receives traffic on ports 80/443
2. The load balancer forwards traffic to NodePort services
3. Kubernetes routes traffic to the appropriate pods

This requires a paid load balancer resource.

## This Cluster's Approach

This cluster binds the ingress controller directly to the host network interface:

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

```text
Internet
    |
    v
DNS (k3s.example.com -> 132.226.43.62)
    |
    v
Ingress Node Public IP (132.226.43.62:443)
    |
    v
Envoy Container (hostPort 443)
    |
    v
Gateway API HTTPRoute
    |
    v
Backend Service (ClusterIP)
    |
    v
Application Pod
```

## Why hostPort Instead of hostNetwork

Using `hostNetwork: true` would give the pod the host's network namespace. This causes DNS resolution issues because the host's `/etc/resolv.conf` does not know about Kubernetes services.

Using `hostPort` keeps the pod in the cluster network namespace while still binding to host ports. The pod can resolve Kubernetes services via CoreDNS.

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
