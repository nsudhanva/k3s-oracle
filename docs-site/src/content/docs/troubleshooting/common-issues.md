---
title: Common Issues
---

```mermaid
flowchart TB
    subgraph Issues["Common Issues"]
        OOC[Out of Capacity]
        ARM[ARM64 Images]
        FW[Firewall Blocking]
        DNS[DNS Not Resolving]
    end

    subgraph Solutions["Solutions"]
        AD[Change Availability Domain]
        Multi[Multi-arch Build]
        IPT[iptables -P ACCEPT]
        Annot[Add DNS Annotation]
    end

    OOC --> AD
    ARM --> Multi
    FW --> IPT
    DNS --> Annot
```

## Out of Capacity

Ampere A1 instances are frequently unavailable in popular regions.

```mermaid
flowchart LR
    subgraph Problem
        OCI[OCI API] -->|Out of Capacity| Fail[Provisioning Failed]
    end

    subgraph Solution
        AD0[AD-0] -.->|try| OCI2[OCI API]
        AD1[AD-1] -.->|try| OCI2
        AD2[AD-2] -.->|try| OCI2
        OCI2 --> Success[Provisioning OK]
    end
```

Try changing the `availability_domain` index in `compute.tf` to 0, 1, or 2.

## ARM64 Image Architecture

Standard container images often fail with `exec format error` on ARM64 nodes.

Build multi-architecture images using GitHub Actions with `docker/setup-qemu-action` for `linux/amd64,linux/arm64`.

## Persistent Storage

K3s uses `local-path-provisioner` by default. For block volumes, implement the OCI CSI driver.

## SSH Tunneling

The API server is not publicly accessible. Create an SSH tunnel:

```bash
ssh -N -L 16443:10.0.2.10:6443 ubuntu@<ingress-ip>
```

See [Accessing the Cluster](/operation/accessing-cluster/) for complete instructions.

## Firewall Blocking CNI Traffic

OCI Ubuntu images have strict iptables rules that block Flannel VXLAN traffic.

```mermaid
flowchart LR
    subgraph Before["Before Fix"]
        Pod1[Pod A] -->|VXLAN| FW[iptables<br/>DROP]
        FW -.->|Blocked| Pod2[Pod B]
    end

    subgraph After["After Fix"]
        Pod3[Pod A] -->|VXLAN| FW2[iptables<br/>ACCEPT]
        FW2 --> Pod4[Pod B]
    end
```

Symptom: Pods cannot resolve DNS with `i/o timeout` errors.

Fix:

```bash
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -F
sudo netfilter-persistent save
```

Cloud-init applies these rules automatically.

## Argo CD Helm Chart Errors

When using Kustomize to inflate Helm charts, Argo CD requires explicit enablement.

Error: `must specify --enable-helm`

Fix: Patch `argocd-cm` ConfigMap:

```yaml
data:
  kustomize.buildOptions: "--enable-helm"
```

## SSH Key Format

OCI requires OpenSSH formatted public keys, not PEM format.

Convert PEM keys:

```bash
ssh-keygen -y -f ~/.oci/oci_api_key.pem > ssh_key.pub
```

## Docker Hub Rate Limiting

Docker Hub rate-limits OCI artifact requests from cloud IPs.

Use Git-based installation for Envoy Gateway instead of Helm OCI.

## External DNS Zone ID Discovery

Scoped Cloudflare API tokens may fail to discover the zone ID automatically.

Error: `Could not route to /client/v4/zones//dns_records...`

Fix: Explicitly provide the zone ID with `--zone-id-filter=<zone-id>`.

## Gateway API External DNS Integration

External DNS may not detect HTTPRoute targets if the Gateway status address is internal.

Fix: Add the annotation `external-dns.alpha.kubernetes.io/target: <public-ip>` to the HTTPRoute.
