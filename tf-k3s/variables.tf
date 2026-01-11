variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API Key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI API private key"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
}

variable "compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH Public Key to use for instances."
  type        = string
  default     = "./oci_key.pub"
}

variable "ssh_source_cidr" {
  description = "CIDR block allowed to SSH into the Ingress node. Defaults to 0.0.0.0/0 (open to world)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone.DNS permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the cluster"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD"
  type        = string
}

variable "git_pat" {
  description = "GitHub Personal Access Token for cloning the private repository."
  type        = string
  sensitive   = true
}

variable "git_username" {
  description = "GitHub Username for the PAT."
  type        = string
  default     = "git"
}

variable "git_repo_name" {
  description = "The repository name (e.g. k3s-oracle) to construct GHCR image paths."
  type        = string
  default     = "k3s-oracle"
}

variable "k3s_token" {
  description = "Shared secret for K3s. If empty, one creates automatically (but passing via var is safer for consistency)."
  type        = string
  default     = "k3s-secret-token-change-me"
}

variable "ingress_private_ip" {
  description = "Static Private IP for the Ingress/NAT node"
  type        = string
  default     = "10.0.1.10"
}

variable "common_tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default = {
    Project     = "k3s-oracle-free"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password to store in OCI Vault"
  type        = string
  sensitive   = true
}

variable "argocd_admin_password_hash" {
  description = "Bcrypt hash of ArgoCD admin password for argocd-secret"
  type        = string
  sensitive   = true
}

variable "git_email" {
  description = "Email address for GitHub container registry authentication"
  type        = string
}
