resource "oci_identity_dynamic_group" "k3s_nodes" {
  compartment_id = var.tenancy_ocid
  name           = "k3s-nodes-dg"
  description    = "Dynamic group for K3s nodes to access OCI Vault"
  matching_rule  = "tag.Project.value = 'k3s-oracle-free'"
}

resource "oci_identity_policy" "k3s_secrets_policy" {
  compartment_id = var.compartment_ocid
  name           = "k3s-secrets-read-policy"
  description    = "Allow K3s nodes to read secrets from Vault"

  statements = [
    "Allow dynamic-group k3s-nodes-dg to read secret-bundles in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group k3s-nodes-dg to read secret-bundle-versions in compartment id ${var.compartment_ocid}"
  ]
}
