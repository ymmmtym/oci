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

