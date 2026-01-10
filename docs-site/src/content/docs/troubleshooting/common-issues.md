---
title: Troubleshooting & Lessons
---

# Lessons Learned

Building a cluster on Always Free OCI requires specific workarounds.

## 1. Out of Capacity

The Ampere A1 (ARM64) instances are often "Out of Capacity" in popular regions (like US-Ashburn).

- **Strategy**: If Terraform fails, try changing the `availability_domain` index in `compute.tf` (0, 1, or 2).

## 2. Image Architecture (ARM64)

Deploying a standard `nginx` or `node` image often fails with `exec format error`.

- **Fix**: Use GitHub Actions with `docker/setup-qemu-action` to build multi-arch images

  (`linux/amd64,linux/arm64`).

## 3. Persistent Storage

OCI Block Volumes are "Always Free" up to 200GB.

- **Implementation**: K3s uses `local-path-provisioner` by default. For real block volumes, the OCI CSI driver is required (not implemented in this basic setup).

## 4. SSH Tunneling

Since the API server is private, you cannot run `kubectl` from your Mac directly.

- **Fix**: Open an SSH tunnel to the Ingress node:

  ```bash
  ssh -L 6443:10.0.2.10:6443 ubuntu@<ingress-ip>
  ```

## 5. Network & CNI (Firewall)

OCI Ubuntu images have strict `iptables` that can block Flannel VXLAN (UDP 8472) traffic between nodes, causing DNS timeouts inside the cluster.

- **Symptom**: Pods cannot resolve DNS (`i/o timeout` lookup `kubernetes.default`).
- **Fix**: Flush default rules. Cloud-init handles this, but if it fails:

  ```bash
  sudo iptables -P INPUT ACCEPT
  sudo iptables -P FORWARD ACCEPT
  sudo iptables -F
  sudo netfilter-persistent save
  ```

## 6. Argo CD & Helm Charts

When using Kustomize to inflate Helm Charts (like `cert-manager`), Argo CD requires explicit enablement.

- **Error**: `must specify --enable-helm`.
- **Fix**: Patch `argocd-cm` ConfigMap in the `argocd-self-managed` application.

  ```yaml
  data:
    kustomize.buildOptions: "--enable-helm"
  ```

## 7. SSH Key Format

OCI Metadata requires OpenSSH formatted public keys (`ssh-rsa ...`), not PEM format (`-----BEGIN...`).

- **Fix**: Convert PEM keys before using in Terraform.

  ```bash
  ssh-keygen -y -f ~/.oci/oci_api_key.pem > oci_key.pub
  ```

## 8. Envoy Gateway & Docker Hub OCI

Docker Hub often rate-limits or blocks OCI artifact requests (`oci://`) from Cloud IPs without authentication (`401 Unauthorized`).

- **Fix**: Use the Git-based installation method instead of Helm OCI for Envoy Gateway. The `kustomization.yaml` should point to the raw `install.yaml` from the GitHub release.

## 9. External DNS & Cloudflare Zone ID

If your Cloudflare API Token is scoped to specific zones, `external-dns` (and `cert-manager`) might fail to discover the Zone ID automatically.

- **Error**: `Could not route to /client/v4/zones//dns_records...` (empty zone ID).
- **Fix**: Explicitly provide the Zone ID in the configuration.
  - For `external-dns`: Use `--zone-id-filter=<zone-id>`.
  - For `cert-manager`: Ensure the Token has `Zone:Read` permission or use an API Key (Global) if discovery fails persistently.

## 10. Gateway API & External DNS

External DNS might not pick up `HTTPRoute` targets automatically if the Gateway status address is internal.

- **Fix**: Add the annotation `external-dns.alpha.kubernetes.io/target: <public-ip>` to the `HTTPRoute` or `Gateway`.
