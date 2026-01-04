output "ingress_public_ip" {
  value = oci_core_instance.ingress.public_ip
}

output "server_private_ip" {
  value = oci_core_instance.server.private_ip
}

output "worker_private_ip" {
  value = oci_core_instance.worker.private_ip
}

output "kubeconfig_command" {
  value = "ssh -i <private_key> ubuntu@${oci_core_instance.ingress.public_ip} 'ssh ubuntu@10.0.2.10 sudo cat /etc/rancher/k3s/k3s.yaml'"
}

output "domain_url" {
  value = "https://${var.domain_name}"
}

output "next_steps" {
  value = <<EOT
1. Copy the generated files from 'argocd/' to your Git repository: ${var.git_repo_url}
2. Push the changes to the repository.
3. Wait for the instances to provision and K3s to install.
4. Verify Argo CD status:
   ssh -J ubuntu@${oci_core_instance.ingress.public_ip} ubuntu@10.0.2.10 "sudo kubectl get applications -n argocd"
EOT
}
