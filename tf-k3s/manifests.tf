resource "local_file" "argocd_apps" {
  filename = "../argocd/applications.yaml"
  content = templatefile("${path.module}/templates/manifests/applications.yaml.tpl", {
    git_repo_url = var.git_repo_url
  })
}

resource "local_file" "cert_manager_kustomization" {
  filename = "../argocd/infrastructure/cert-manager/kustomization.yaml"
  content  = file("${path.module}/templates/manifests/cert-manager/kustomization.yaml")
}

resource "local_file" "cert_manager_cluster_issuer" {
  filename = "../argocd/infrastructure/cert-manager/cluster-issuer.yaml"
  content = templatefile("${path.module}/templates/manifests/cert-manager/cluster-issuer.yaml.tpl", {
    email = var.acme_email
  })
}

resource "local_file" "external_dns_kustomization" {
  filename = "../argocd/infrastructure/external-dns/kustomization.yaml"
  content = templatefile("${path.module}/templates/manifests/external-dns/kustomization.yaml.tpl", {
    domain_name = var.domain_name
  })
}

resource "local_file" "external_dns_rbac" {
  for_each = { for f in fileset("${path.module}/templates/manifests/external-dns", "*.yaml*") : f => f if f != "kustomization.yaml.tpl" }
  filename = "../argocd/infrastructure/external-dns/${replace(each.value, ".tpl", "")}"
  content  = file("${path.module}/templates/manifests/external-dns/${each.value}")
}

resource "local_file" "envoy_gateway_config" {
  filename = "../argocd/infrastructure/envoy-gateway/config.yaml"
  content = templatefile("${path.module}/templates/manifests/envoy-gateway/config.yaml.tpl", {
    domain_name = var.domain_name
  })
}

resource "local_file" "envoy_gateway_kustomization" {
  filename = "../argocd/infrastructure/envoy-gateway/kustomization.yaml"
  content  = file("${path.module}/templates/manifests/envoy-gateway/kustomization.yaml")
}

resource "local_file" "envoy_gateway_static_dns" {
  filename = "../argocd/infrastructure/envoy-gateway/static-dns.yaml"
  content = templatefile("${path.module}/templates/manifests/envoy-gateway/static-dns.yaml.tpl", {
    domain_name       = var.domain_name
    ingress_public_ip = oci_network_load_balancer_network_load_balancer.k3s_nlb.ip_addresses[0].ip_address
  })
}

resource "local_file" "argocd_ingress_manifests" {
  filename = "../argocd/infrastructure/argocd-ingress/ingress.yaml"
  content = templatefile("${path.module}/templates/manifests/argocd-ingress/ingress.yaml.tpl", {
    domain_name = var.domain_name
  })
}

resource "local_file" "argocd_self_managed" {
  filename = "../argocd/infrastructure/argocd/kustomization.yaml"
  content  = file("${path.module}/templates/manifests/argocd/kustomization.yaml")
}

resource "local_file" "docs_manifests" {
  for_each = fileset("${path.module}/templates/manifests/docs", "*")
  filename = "../argocd/apps/docs/${replace(each.value, ".tpl", "")}"
  content = templatefile("${path.module}/templates/manifests/docs/${each.value}", {
    domain_name       = var.domain_name
    git_username      = var.git_username
    git_repo_name     = var.git_repo_name
    ingress_public_ip = oci_network_load_balancer_network_load_balancer.k3s_nlb.ip_addresses[0].ip_address
  })
}

# External Secrets Operator Helm release
resource "local_file" "external_secrets_manifests" {
  for_each = fileset("${path.module}/templates/manifests/external-secrets", "*")
  filename = "../argocd/infrastructure/external-secrets/${each.value}"
  content  = file("${path.module}/templates/manifests/external-secrets/${each.value}")
}

# Managed Secrets (ClusterSecretStore + ExternalSecrets) - templated with sensitive values
resource "local_file" "managed_secrets_kustomization" {
  filename = "../argocd/infrastructure/managed-secrets/kustomization.yaml"
  content  = file("${path.module}/templates/manifests/managed-secrets/kustomization.yaml")
}

resource "local_file" "managed_secrets_secrets" {
  filename = "../argocd/infrastructure/managed-secrets/secrets.yaml"
  content = templatefile("${path.module}/templates/manifests/managed-secrets/secrets.yaml.tpl", {
    vault_ocid   = oci_kms_vault.k3s_vault.id
    oci_region   = var.region
    git_username = var.git_username
    git_email    = var.git_email
    git_repo_url = var.git_repo_url
  })
}
