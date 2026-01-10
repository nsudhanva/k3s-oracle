---
title: Accessing the Cluster
---

Because the K3s Control Plane (`server` node) resides in a **Private Subnet**, you cannot connect to it directly from the internet. You must use the **Ingress Node** as a jump host (bastion).

## Quick Reference

Get connection details from Terraform:

```bash
cd tf-k3s
terraform output
```

This will show you:

- `ingress_public_ip` - Public IP of the ingress/bastion node
- `server_private_ip` - Private IP of the K3s server (usually `10.0.2.10`)
- `worker_private_ip` - Private IP of the worker node

## SSH Access

To SSH into the nodes:

1. **Ingress Node** (Public):

   ```bash
   ssh -i /path/to/key.pem ubuntu@<ingress-public-ip>
   ```

2. **Server Node** (Private) via Jump Host:

   ```bash
   ssh -i /path/to/key.pem -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10
   ```

3. **Worker Node** (Private) via Jump Host:

   ```bash
   ssh -i /path/to/key.pem -J ubuntu@<ingress-public-ip> ubuntu@<worker-private-ip>
   ```

## Kubectl Access

To use `kubectl` from your local machine, you need to set up an SSH tunnel and configure your kubeconfig.

### Step 1: Start the SSH Tunnel

Open a terminal and start the tunnel (keep this running):

```bash
ssh -N -L 16443:10.0.2.10:6443 ubuntu@<ingress-public-ip>
```

:::tip
We use port `16443` locally to avoid conflicts with any local Kubernetes cluster running on port `6443`.
:::

### Step 2: Fetch and Configure Kubeconfig

In a new terminal, fetch the kubeconfig from the server:

```bash
# Create the .kube directory if it doesn't exist
mkdir -p ~/.kube

# Fetch kubeconfig and update server address and context name
ssh -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10 "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed 's|server: https://127.0.0.1:6443|server: https://127.0.0.1:16443|g' | \
  sed 's|name: default|name: k3s-oracle|g' | \
  sed 's|cluster: default|cluster: k3s-oracle|g' | \
  sed 's|user: default|user: k3s-oracle|g' | \
  sed 's|current-context: default|current-context: k3s-oracle|g' \
  > ~/.kube/k3s-oracle.yaml
```

### Step 3: Merge into Main Kubeconfig (Optional)

To use `kubectl config use-context k3s-oracle` alongside other clusters:

```bash
# Backup existing config
cp ~/.kube/config ~/.kube/config.backup

# Merge kubeconfigs
KUBECONFIG=~/.kube/config:~/.kube/k3s-oracle.yaml kubectl config view --flatten > ~/.kube/config.merged
mv ~/.kube/config.merged ~/.kube/config

# Set k3s-oracle as current context
kubectl config use-context k3s-oracle
```

### Step 4: Verify Connection

```bash
kubectl get nodes
```

Expected output:

```
NAME       STATUS   ROLES           AGE   VERSION
ingress    Ready    <none>          1h    v1.34.3+k3s1
server     Ready    control-plane   1h    v1.34.3+k3s1
worker-1   Ready    <none>          1h    v1.34.3+k3s1
```

### Using the Standalone Kubeconfig

If you prefer not to merge, you can use the standalone kubeconfig:

```bash
KUBECONFIG=~/.kube/k3s-oracle.yaml kubectl get nodes
```

Or set it for your shell session:

```bash
export KUBECONFIG=~/.kube/k3s-oracle.yaml
kubectl get nodes
```

### Quick Remote Command Execution

For quick checks without setting up a tunnel:

```bash
ssh -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10 "sudo kubectl get pods -A"
```

## Argo CD UI

Argo CD manages all deployments on the cluster. If the `argocd-ingress` application is configured, it's exposed at `https://cd.<your-domain>`.

### Option 1: Via Public Ingress (if configured)

If your Argo CD ingress is set up, visit:

```
https://cd.<your-domain>
```

### Option 2: Via Port Forward

If not exposed publicly, use port forwarding:

1. **Start Port Forward**:

   ```bash
   ssh -L 8080:localhost:8080 -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10 \
   "sudo kubectl port-forward svc/argocd-server -n argocd 8080:443"
   ```

2. **Open Browser**:
   Visit `https://localhost:8080` (accept the self-signed certificate warning).

### Login Credentials

- **Username**: `admin`
- **Password**: Retrieve from the cluster:

  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  ```

  Or via SSH:

  ```bash
  ssh -J ubuntu@<ingress-public-ip> ubuntu@10.0.2.10 \
  "sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  ```

## Troubleshooting

### SSH Connection Issues

**Host key verification failed:**

```bash
# Remove old host keys if the cluster was recreated
ssh-keygen -R <ingress-public-ip>
```

**Connection timeout:**

- Verify the ingress node is running in OCI Console
- Check security list rules allow SSH (port 22) from your IP

### Kubectl Connection Issues

**Connection refused on port 16443:**

- Ensure the SSH tunnel is running in another terminal
- Verify the tunnel command completed without errors

**Certificate error:**

- The kubeconfig contains embedded certificates
- Re-fetch the kubeconfig if the cluster was rebuilt

### Tunnel Keeps Disconnecting

For persistent tunnels, use autossh:

```bash
# Install autossh (macOS)
brew install autossh

# Start auto-reconnecting tunnel
autossh -M 0 -N -L 16443:10.0.2.10:6443 ubuntu@<ingress-public-ip>
```

Or add SSH keep-alive options:

```bash
ssh -N -L 16443:10.0.2.10:6443 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 ubuntu@<ingress-public-ip>
```
