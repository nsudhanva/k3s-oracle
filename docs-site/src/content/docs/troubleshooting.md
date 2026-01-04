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
