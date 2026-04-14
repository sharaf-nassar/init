locals {
  compartment_id = var.compartment_id != "" ? var.compartment_id : var.tenancy_ocid
}

# ──────────────────────────────────────────────
# Virtual Cloud Network
# ──────────────────────────────────────────────

resource "oci_core_vcn" "main" {
  compartment_id = local.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "init-vcn"
  dns_label      = "initvcn"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "init-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "init-public-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# ──────────────────────────────────────────────
# Public subnet
# ──────────────────────────────────────────────

resource "oci_core_subnet" "public" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.subnet_cidr
  display_name               = "init-public-subnet"
  dns_label                  = "pubsubnet"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.app.id]
  prohibit_public_ip_on_vnic = false
}

# ──────────────────────────────────────────────
# Security list (firewall rules)
# ──────────────────────────────────────────────

resource "oci_core_security_list" "app" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "init-security-list"

  # --- Egress: allow all outbound traffic ---
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  # --- Ingress: SSH ---
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  # --- Ingress: HTTP ---
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 80
      max = 80
    }
  }

  # --- Ingress: HTTPS ---
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  # --- Ingress: ICMP (path discovery + ping) ---
  ingress_security_rules {
    protocol  = "1" # ICMP
    source    = "0.0.0.0/0"
    stateless = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol  = "1"
    source    = var.vcn_cidr
    stateless = false

    icmp_options {
      type = 3
    }
  }
}
