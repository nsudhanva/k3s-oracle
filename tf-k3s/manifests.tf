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

resource "local_file" "traefik_kustomization" {
  filename = "../argocd/infrastructure/traefik/kustomization.yaml"
  content  = file("${path.module}/templates/manifests/traefik/kustomization.yaml")
}

resource "local_file" "nginx_manifests" {
  for_each = fileset("${path.module}/templates/manifests/nginx", "*")
  filename = "../argocd/apps/nginx/${each.value}"
  content = templatefile("${path.module}/templates/manifests/nginx/${each.value}", {
    domain_name = var.domain_name
  })
}
