---
title: Networking Details
---

# Networking & NAT Routing

Since OCI Always Free does not include a Managed NAT Gateway, we implement a software NAT.

## Topology

- **VCN**: `10.0.0.0/16`
- **Public Subnet**: `10.0.1.0/24`. Only the Ingress node lives here.
- **Private Subnet**: `10.0.2.0/24`. Server and Worker nodes.

## The NAT Node (`k3s-ingress`)

The Ingress node handles all egress traffic for the private subnet.

### Mandatory Configuration (Applied via Cloud-Init)

1. **Enable Forwarding**:

   ```bash
   echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-nat.conf
   sysctl -p /etc/sysctl.d/99-nat.conf
   ```

2. **Iptables Masquerade**:

   ```bash
   iptables -t nat -A POSTROUTING -o enp0s6 -j MASQUERADE
   ```

3. **The "Trap": Firewall Rules**:

   Ubuntu 24.04 on OCI comes with `netfilter-persistent` and a default `REJECT` rule in the `FORWARD` chain. **Packets

   will reach the node but won't exit without these commands**:

   ```bash

   iptables -P FORWARD ACCEPT

   iptables -F FORWARD

   netfilter-persistent save

   ```

## Ingress Traffic

We use the **Kubernetes Gateway API**.

- Traefik runs on the Ingress node with `hostNetwork: true`.
- Ports 80 and 443 are bound directly to the node's public IP.
- Cloudflare DNS points `*.your-domain` to this public IP.
