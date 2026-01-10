---
title: Prerequisites
---

Before you begin, ensure you have the following accounts and tools ready.

## Cloud & Services

### 1. Oracle Cloud (OCI) Account

- **Type**: "Always Free" Tier is sufficient.
- **Resources**: You need availability for **Ampere A1 Compute** instances.
  - *Tip*: US-Ashburn-1 or EU-Frankfurt-1 often have better availability, but it varies.
- **Credentials**: You will need your Tenancy OCID, User OCID, Fingerprint, and Private Key file (`.pem`).

### 2. Cloudflare Account

- **Domain**: You must own a domain (e.g., `example.com`) managed by Cloudflare.
- **API Token**: Create a token with **Edit** permissions for **Zone.DNS**.
  - *Note*: This token is used by `external-dns` to update records and `cert-manager` (if using DNS-01, though we default to HTTP-01 now).

### 3. GitHub Account

- **Repository**: Fork this repository to your private account.
- **Personal Access Token (PAT)**:
  - **Type**: Classic Token.
  - **Scopes**: `repo` (Full control) and `read:packages` (for GHCR).
  - *Usage*: This allows the cluster to pull configuration from your private repo and pull docker images.

## Local Tools

Ensure these are installed on your machine (macOS/Linux/WSL):

### 1. Terraform

- **Version**: >= 1.5.0
- **Purpose**: Provisioning OCI infrastructure and bootstrapping manifests.
- [Installation Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

### 2. OCI CLI (Optional but Recommended)

- **Purpose**: Validating your credentials and checking limits.
- [Installation Guide](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)

### 3. Kubectl

- **Purpose**: Interacting with the cluster.
- [Installation Guide](https://kubernetes.io/docs/tasks/tools/)

### 4. SSH Client

- Standard OpenSSH client (pre-installed on macOS/Linux).
