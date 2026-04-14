# ──────────────────────────────────────────────
# Data sources
# ──────────────────────────────────────────────

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ──────────────────────────────────────────────
# .env file (assembled here, base64-encoded for cloud-init)
# ──────────────────────────────────────────────

locals {
  env_content = join("\n", [
    "DATABASE_URL=postgresql://${var.postgres_user}:${var.postgres_password}@db:5432/${var.postgres_db}",
    "AUTH_SECRET=${var.auth_secret}",
    "AUTH_GITHUB_ID=${var.auth_github_id}",
    "AUTH_GITHUB_SECRET=${var.auth_github_secret}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=${var.postgres_db}",
    "", # trailing newline
  ])
}

# ──────────────────────────────────────────────
# Compute instance
# ──────────────────────────────────────────────

resource "oci_core_instance" "app" {
  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "init-app"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "init-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(
      templatefile("${path.module}/templates/cloud-init.yml.tftpl", {
        caddy_site_address  = var.domain != "" ? var.domain : ":80"
        git_repo_url        = var.git_repo_url
        deploy_private_key  = base64encode(var.deploy_private_key)
        env_file_b64        = base64encode(local.env_content)
      })
    )
  }

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
