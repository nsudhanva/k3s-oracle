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

OCI Ubuntu images have strict iptables rules that block Flannel VXLAN traffic (UDP 8472).

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

Symptom: Pods cannot resolve DNS with `i/o timeout` errors, or pods on the ingress node cannot reach pods on other nodes.

The ingress node requires specific iptables rules because it's in a different subnet (10.0.1.0/24) than the server/worker nodes (10.0.2.0/24):

```bash
sudo iptables -I INPUT -p udp --dport 8472 -j ACCEPT
sudo iptables -I INPUT -s 10.0.2.0/24 -j ACCEPT
sudo iptables -I INPUT -s 10.42.0.0/16 -j ACCEPT
sudo iptables -I FORWARD -s 10.42.0.0/16 -d 10.42.0.0/16 -j ACCEPT
sudo netfilter-persistent save
```

Cloud-init applies these rules automatically.

## Pod-to-Pod Connectivity Issues

If pods on the ingress node (e.g., Envoy) cannot connect to pods on other nodes:

Symptom: Envoy returns `503 Service Unavailable` with `upstream_reset_before_response_started{remote_connection_failure}`.

This occurs when:
1. VXLAN traffic (UDP 8472) is blocked by iptables
2. Traffic from the pod network (10.42.0.0/16) is blocked

Verify connectivity:

```bash
ssh ubuntu@<ingress-ip> "ping -c 2 10.42.0.26"
```

If ping works but TCP doesn't, check iptables INPUT chain for REJECT rules.

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

## Gateway TLS Certificate RefNotPermitted

If the Gateway shows `PROGRAMMED: False` with `RefNotPermitted` errors, it cannot access TLS secrets from other namespaces.

Symptom: `kubectl describe gateway public-gateway` shows:
```
Certificate ref to secret argocd/argocd-tls not permitted by any ReferenceGrant
```

Fix: Create ReferenceGrants in each namespace containing TLS secrets:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-secrets
  namespace: argocd
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: envoy-gateway-system
  to:
  - group: ""
    kind: Secret
```

The Envoy Gateway config template includes these ReferenceGrants automatically.

## Node Label Namespace Restrictions

Kubernetes 1.28+ restricts labels in the `kubernetes.io` and `k8s.io` namespaces.

Symptom: k3s-agent fails to start with error:
```
Error: failed to validate kubelet flags: unknown 'kubernetes.io' or 'k8s.io' labels specified with --node-labels: [node-role.kubernetes.io/ingress]
```

Fix: Use custom labels without the `kubernetes.io` prefix:
```bash
--node-label role=ingress
--node-label role=worker
```

The cloud-init templates use `role=ingress` and `role=worker` which are allowed.

## ArgoCD Application Sync Order

Applications may fail to sync if dependencies aren't deployed yet.

Symptom: `one or more synchronization tasks are not valid` with message about missing CRDs.

Common dependency issues:
1. `envoy-gateway` needs `external-dns` CRD (DNSEndpoint)
2. `docs-app` needs `cert-manager` CRD (Certificate)
3. All apps using Helm charts need `kustomize.buildOptions: "--enable-helm"` in argocd-cm

Fix: Manually sync in order:
```bash
kubectl -n argocd patch application external-dns --type=merge -p '{"operation":{"sync":{}}}'
kubectl -n argocd patch application cert-manager --type=merge -p '{"operation":{"sync":{}}}'
kubectl -n argocd patch application envoy-gateway --type=merge -p '{"operation":{"sync":{}}}'
kubectl -n argocd patch application docs-app --type=merge -p '{"operation":{"sync":{}}}'
```

## ArgoCD Kustomize Helm Support

If applications using Kustomize with helmCharts fail with `must specify --enable-helm`:

Fix: Ensure the argocd-cm ConfigMap has the correct setting:
```bash
kubectl -n argocd patch cm argocd-cm --type=merge -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'
kubectl -n argocd rollout restart deploy argocd-repo-server
```

The ArgoCD kustomization includes this configuration automatically via the argocd-self-managed application.
