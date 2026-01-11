resource "oci_kms_vault" "k3s_vault" {
  compartment_id = var.compartment_ocid
  display_name   = "k3s-secrets-vault"
  vault_type     = "DEFAULT"
  freeform_tags  = var.common_tags
}

resource "oci_kms_key" "master_key" {
  compartment_id      = var.compartment_ocid
  display_name        = "k3s-master-key"
  management_endpoint = oci_kms_vault.k3s_vault.management_endpoint
  protection_mode     = "HSM"
  freeform_tags       = var.common_tags

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

resource "oci_vault_secret" "cloudflare_api_token" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "cloudflare-api-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.cloudflare_api_token)
  }
}

resource "oci_vault_secret" "cloudflare_zone_id" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "cloudflare-zone-id"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.cloudflare_zone_id)
  }
}

resource "oci_vault_secret" "domain_name" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "domain-name"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.domain_name)
  }
}

resource "oci_vault_secret" "github_pat" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "github-pat"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.git_pat)
  }
}

resource "oci_vault_secret" "github_username" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "github-username"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.git_username)
  }
}

resource "oci_vault_secret" "git_repo_url" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "git-repo-url"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.git_repo_url)
  }
}

resource "oci_vault_secret" "k3s_token" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "k3s-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.k3s_token)
  }
}

resource "oci_vault_secret" "acme_email" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "acme-email"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.acme_email)
  }
}

resource "oci_vault_secret" "argocd_admin_password" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "argocd-admin-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.argocd_admin_password)
  }
}

resource "oci_vault_secret" "argocd_admin_password_hash" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "argocd-admin-password-hash"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.argocd_admin_password_hash)
  }
}

resource "oci_vault_secret" "ssh_public_key" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.k3s_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "ssh-public-key"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(local.ssh_public_key)
  }
}

output "vault_ocid" {
  value       = oci_kms_vault.k3s_vault.id
  description = "OCI Vault OCID for secret retrieval"
}

output "vault_management_endpoint" {
  value       = oci_kms_vault.k3s_vault.management_endpoint
  description = "OCI Vault management endpoint"
}

output "secret_ocids" {
  value = {
    cloudflare_api_token       = oci_vault_secret.cloudflare_api_token.id
    cloudflare_zone_id         = oci_vault_secret.cloudflare_zone_id.id
    domain_name                = oci_vault_secret.domain_name.id
    github_pat                 = oci_vault_secret.github_pat.id
    github_username            = oci_vault_secret.github_username.id
    git_repo_url               = oci_vault_secret.git_repo_url.id
    k3s_token                  = oci_vault_secret.k3s_token.id
    acme_email                 = oci_vault_secret.acme_email.id
    argocd_admin_password      = oci_vault_secret.argocd_admin_password.id
    argocd_admin_password_hash = oci_vault_secret.argocd_admin_password_hash.id
    ssh_public_key             = oci_vault_secret.ssh_public_key.id
  }
  description = "Map of secret names to their OCIDs for retrieval"
  sensitive   = true
}
