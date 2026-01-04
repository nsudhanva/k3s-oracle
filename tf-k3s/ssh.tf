resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

output "generated_private_key" {
  value     = var.my_ssh_public_key == "" ? tls_private_key.ssh.private_key_pem : "User provided key used."
  sensitive = true
}

locals {
  ssh_public_key = var.my_ssh_public_key == "" ? tls_private_key.ssh.public_key_openssh : var.my_ssh_public_key
}
