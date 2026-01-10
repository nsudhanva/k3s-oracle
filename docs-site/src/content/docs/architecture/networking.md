---
title: Networking
---

OCI Always Free does not include a managed NAT Gateway. This cluster implements software NAT on the ingress node.

```mermaid
graph TB
    subgraph Internet
        WWW((Internet))
    end

    subgraph OCI["OCI VCN (10.0.0.0/16)"]
        IGW[Internet Gateway]

        subgraph Public["Public Subnet (10.0.1.0/24)"]
            Ingress[k3s-ingress<br/>10.0.1.x<br/>+ Public IP]
        end

        subgraph Private["Private Subnet (10.0.2.0/24)"]
            Server[k3s-server<br/>10.0.2.10]
            Worker[k3s-worker<br/>10.0.2.11]
        end
    end

    WWW <-->|Inbound/Outbound| IGW
    IGW <--> Ingress
    Ingress <-->|NAT| Server
    Ingress <-->|NAT| Worker
    Server <--> Worker
```

## Network Topology

| Subnet | CIDR | Nodes |
|--------|------|-------|
| Public | 10.0.1.0/24 | k3s-ingress |
| Private | 10.0.2.0/24 | k3s-server, k3s-worker |

The VCN uses CIDR 10.0.0.0/16 with an internet gateway attached to the public subnet.

## NAT Configuration

The ingress node routes egress traffic for the private subnet. Cloud-init applies these configurations:

```mermaid
sequenceDiagram
    participant Server as k3s-server<br/>(10.0.2.10)
    participant Ingress as k3s-ingress<br/>(10.0.1.x)
    participant IGW as Internet Gateway
    participant Internet as Internet

    Note over Server,Ingress: Private → Public Subnet
    Server->>Ingress: Packet (src: 10.0.2.10)
    Note over Ingress: iptables MASQUERADE<br/>SNAT: 10.0.2.10 → Public IP
    Ingress->>IGW: Packet (src: Public IP)
    IGW->>Internet: Outbound traffic

    Internet->>IGW: Response
    IGW->>Ingress: Response (dst: Public IP)
    Note over Ingress: Connection tracking<br/>DNAT: Public IP → 10.0.2.10
    Ingress->>Server: Response (dst: 10.0.2.10)
```

### IP Forwarding

```bash
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-nat.conf
sysctl -p /etc/sysctl.d/99-nat.conf
```

### Masquerade

```bash
iptables -t nat -A POSTROUTING -o enp0s6 -j MASQUERADE
```

### Firewall Rules

Ubuntu 24.04 on OCI includes restrictive iptables rules that block forwarded traffic:

```bash
iptables -P FORWARD ACCEPT
iptables -F FORWARD
netfilter-persistent save
```

```mermaid
flowchart LR
    subgraph Before["Before: Traffic Blocked"]
        P1[Private Subnet] -->|FORWARD| FW1[iptables<br/>POLICY: DROP]
        FW1 -.->|Blocked| I1[Ingress]
    end

    subgraph After["After: Traffic Allowed"]
        P2[Private Subnet] -->|FORWARD| FW2[iptables<br/>POLICY: ACCEPT]
        FW2 -->|Forwarded| I2[Ingress]
        I2 -->|MASQUERADE| Int[Internet]
    end
```

## Ingress Traffic

Envoy Gateway handles inbound traffic using hostPort binding instead of hostNetwork. This approach maintains cluster network connectivity while exposing ports 80 and 443 on the host interface.

Configuration via EnvoyProxy custom resource:

```yaml
spec:
  provider:
    kubernetes:
      envoyDeployment:
        pod:
          nodeSelector:
            role: ingress
        patch:
          value:
            spec:
              containers:
                - name: envoy
                  ports:
                    - containerPort: 80
                      hostPort: 80
                    - containerPort: 443
                      hostPort: 443
```

## DNS

External DNS watches HTTPRoute resources and updates Cloudflare A records. The `external-dns.alpha.kubernetes.io/target` annotation specifies the ingress node public IP for each route.

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant Argo as Argo CD
    participant ED as External DNS
    participant CF as Cloudflare
    participant User as User

    Dev->>GH: Push HTTPRoute with annotation
    GH->>Argo: Webhook trigger
    Argo->>Argo: Sync HTTPRoute
    ED->>ED: Watch HTTPRoute
    ED->>CF: Create/Update A record<br/>k3s.example.com → 132.226.43.62
    User->>CF: DNS query: k3s.example.com
    CF->>User: 132.226.43.62
    User->>User: Connect to ingress node
```

```mermaid
flowchart LR
    subgraph Cluster["K3s Cluster"]
        HR[HTTPRoute<br/>+ annotation]
        ED[External DNS]
    end

    subgraph Cloudflare
        DNS[(DNS Zone)]
    end

    HR -->|watches| ED
    ED -->|API call| DNS
    DNS -->|A Record| IP[132.226.43.62]
```
