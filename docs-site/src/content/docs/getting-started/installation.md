---
title: Installation
---

## Provisioning

After creating `terraform.tfvars`, run Terraform to provision the infrastructure:

```bash
cd tf-k3s
terraform init
terraform apply
```

Terraform creates the OCI networking and compute instances, then generates Kubernetes manifests in the `argocd/` directory.

## Push Manifests

The generated manifests must be committed to your repository for Argo CD to sync them:

```bash
cd ..
git add argocd/
git commit -m "Configure cluster manifests"
git push
```

## Bootstrapping

Cloud-init scripts automatically configure each node:

- Ingress node enables IP forwarding and NAT
- Server node installs K3s and Argo CD
- Worker node joins the cluster

Allow approximately five minutes for all nodes to initialize and Argo CD to begin syncing.

## Verification

### Check Nodes

```bash
terraform output
ssh -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10 "sudo kubectl get nodes"
```

Expected output:

```text
NAME       STATUS   ROLES           AGE   VERSION
ingress    Ready    <none>          5m    v1.34.3+k3s1
server     Ready    control-plane   5m    v1.34.3+k3s1
worker-1   Ready    <none>          5m    v1.34.3+k3s1
```

### Check Applications

```bash
ssh -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10 "sudo kubectl get applications -n argocd"
```

Expected output:

```text
NAME                  SYNC STATUS   HEALTH STATUS
argocd-ingress        Synced        Healthy
argocd-self-managed   Synced        Healthy
cert-manager          Synced        Healthy
docs-app              Synced        Healthy
envoy-gateway         Synced        Healthy
external-dns          Synced        Healthy
gateway-api-crds      Synced        Healthy
root-app              Synced        Healthy
```

### Check Pods

```bash
ssh -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10 "sudo kubectl get pods -A"
```

All pods should be Running except for completed Job pods.

### Verify DNS and TLS

After a few minutes, test the deployed application:

```bash
dig +short k3s.yourdomain.com
curl -I https://k3s.yourdomain.com
```

## Next Steps

- [Set up local kubectl access](/operation/accessing-cluster/)
- [Deploy applications](/operation/deploying-apps/)
