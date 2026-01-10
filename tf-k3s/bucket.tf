data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "k3s-tfstate"
  access_type    = "NoPublicAccess"
  versioning     = "Enabled"
  freeform_tags  = var.common_tags
}

output "tfstate_bucket_name" {
  value       = oci_objectstorage_bucket.tfstate.name
  description = "Object Storage bucket name for state backend"
}

output "tfstate_bucket_namespace" {
  value       = data.oci_objectstorage_namespace.ns.namespace
  description = "Object Storage namespace for backend configuration"
}
