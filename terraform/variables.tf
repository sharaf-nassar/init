# ──────────────────────────────────────────────
# OCI authentication
# ──────────────────────────────────────────────

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user for API key auth"
  type        = string
}

variable "private_key_path" {
  description = "Path to the OCI API private key PEM file"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API public key"
  type        = string
}

variable "region" {
  description = "OCI region (e.g. us-ashburn-1, eu-frankfurt-1)"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment to create resources in (defaults to tenancy root)"
  type        = string
  default     = ""
}

# ──────────────────────────────────────────────
# Compute instance
# ──────────────────────────────────────────────

variable "instance_shape" {
  description = "OCI compute shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs for the flex shape"
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory in GB for the flex shape"
  type        = number
  default     = 12
}

variable "boot_volume_gb" {
  description = "Boot volume size in GB (free tier: up to 200 total)"
  type        = number
  default     = 100

  validation {
    condition     = var.boot_volume_gb >= 50 && var.boot_volume_gb <= 200
    error_message = "Boot volume must be between 50 and 200 GB."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for VM access (contents, not path)"
  type        = string
}

# ──────────────────────────────────────────────
# Application
# ──────────────────────────────────────────────

variable "domain" {
  description = "Domain name for Caddy HTTPS (e.g. app.example.com). Leave empty to serve plain HTTP on port 80."
  type        = string
  default     = ""
}

variable "git_repo_url" {
  description = "SSH clone URL (e.g. git@github.com:user/repo.git)"
  type        = string
}

variable "deploy_private_key" {
  description = "SSH private key for cloning the repo (deploy key)"
  type        = string
  sensitive   = true
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "t3app"
}

variable "auth_secret" {
  description = "Auth.js encryption secret (min 32 chars)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.auth_secret) >= 32
    error_message = "AUTH_SECRET must be at least 32 characters."
  }
}

variable "auth_github_id" {
  description = "GitHub OAuth Client ID (optional)"
  type        = string
  default     = ""
}

variable "auth_github_secret" {
  description = "GitHub OAuth Client Secret (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

# ──────────────────────────────────────────────
# Network
# ──────────────────────────────────────────────

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}
