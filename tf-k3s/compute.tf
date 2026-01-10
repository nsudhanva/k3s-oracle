data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  ssh_public_key = file(var.ssh_public_key_path)
}

# --- Ingress / NAT Instance (Public) ---
resource "oci_core_instance" "ingress" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "k3s-ingress"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = var.common_tags

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id              = oci_core_subnet.public_subnet.id
    assign_public_ip       = true
    private_ip             = var.ingress_private_ip # 10.0.1.10
    skip_source_dest_check = true
    hostname_label         = "ingress"
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/ingress.yaml", {
      server_ip = "10.0.2.10"
      k3s_token = var.k3s_token
    }))
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }
}

# --- Private Network Routing ---
# Must be created after Ingress instance to get its Private IP OCID
data "oci_core_private_ips" "ingress_ips" {
  subnet_id  = oci_core_subnet.public_subnet.id
  ip_address = var.ingress_private_ip

  depends_on = [oci_core_instance.ingress]
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k3s_vcn.id
  display_name   = "k3s-private-rt"
  freeform_tags  = var.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = data.oci_core_private_ips.ingress_ips.private_ips[0].id
  }
}

resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.k3s_vcn.id
  cidr_block                 = "10.0.2.0/24"
  display_name               = "k3s-private-subnet"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private_rt.id
  security_list_ids          = [oci_core_security_list.private_sl.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = var.common_tags
}

# --- Server Instance (Private) ---
resource "oci_core_instance" "server" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "k3s-server"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = var.common_tags

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.private_subnet.id
    assign_public_ip = false
    private_ip       = "10.0.2.10"
    hostname_label   = "server"
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/server.yaml", {
      public_ip            = oci_core_instance.ingress.public_ip
      k3s_token            = var.k3s_token
      git_repo_url         = var.git_repo_url
      git_pat              = var.git_pat
      git_username         = var.git_username
      cloudflare_api_token = var.cloudflare_api_token
    }))
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }
}

# --- Worker Instance (Private) ---
resource "oci_core_instance" "worker" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "k3s-worker"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = var.common_tags

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.private_subnet.id
    assign_public_ip = false
    hostname_label   = "worker-1"
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/worker.yaml", {
      server_ip = "10.0.2.10"
      k3s_token = var.k3s_token
    }))
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }
}
