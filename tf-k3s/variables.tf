variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}
variable "compartment_ocid" {}

variable "ssh_public_key_path" {
  description = "Path to the SSH Public Key to use for instances."
  type        = string
  default     = "/Users/sudhanva/.oci/oci_api_key_public.pem"
}

variable "ssh_source_cidr" {
  description = "CIDR block allowed to SSH into the Ingress node. Defaults to 0.0.0.0/0 (open to world)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "cloudflare_api_token" {
  sensitive = true
}

variable "cloudflare_zone_id" {}
variable "domain_name" {}

variable "git_repo_url" {}

variable "git_pat" {
  description = "GitHub Personal Access Token for cloning the private repository."
  sensitive   = true
}

variable "git_username" {
  description = "GitHub Username for the PAT."
  default     = "git"
}

variable "git_repo_name" {
  description = "The repository name (e.g. k3s-oracle) to construct GHCR image paths."
  default     = "k3s-oracle"
}

variable "k3s_token" {
  description = "Shared secret for K3s. If empty, one creates automatically (but passing via var is safer for consistency)."
  default     = "k3s-secret-token-change-me"
}

variable "ingress_private_ip" {
  description = "Static Private IP for the Ingress/NAT node"
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