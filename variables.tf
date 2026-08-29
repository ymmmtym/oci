variable "fingerprint" {
  description = "Fingerprint of OCI API private key for Tenancy"
  type        = string
}

variable "private_key" {
  description = "OCI API private key used for Tenancy"
  type        = string
  sensitive   = true
}

variable "tenancy_ocid" {
  description = "Tenancy ID where to create resources for Tenancy"
  type        = string
}

variable "user_ocid" {
  description = "Usek ID that Terraform will use to create resources for Tenancy"
  type        = string
}

variable "region" {
  description = "OCI region where resources will be created for Tenancy"
  type        = string
  default     = "ap-osaka-1"
}

variable "adb_admin_password" {
  description = "Autonomous Database admin password (12-30 chars, must include 1 uppercase, 1 lowercase, 1 number, 1 special char)"
  type        = string
  sensitive   = true
}

variable "ubuntu_image_ocid" {
  description = "Pinned OCID of Canonical Ubuntu 22.04 image for VM.Standard.E2.1.Micro in ap-osaka-1. Prevents instance recreation when OCI publishes new images. Bump intentionally via PR when upgrading."
  type        = string
  default     = "ocid1.image.oc1.ap-osaka-1.aaaaaaaaft5c7or3dimnzqraj2izb5xmswuofwbuhwmnhbpw7pubiwcv6wlq" # Canonical-Ubuntu-22.04-2026.06.29-0
}

