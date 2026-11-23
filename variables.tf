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
  description = "Pinned OCID of Canonical Ubuntu 26.04 Minimal image for VM.Standard.E2.1.Micro in ap-osaka-1. Prevents instance recreation when OCI publishes new images. Bump intentionally via PR when upgrading."
  type        = string
  default     = "ocid1.image.oc1.ap-osaka-1.aaaaaaaaxjdpvxyc3i5lle36mhkbcamarv4tsu2vue3arafpjd5zroyogcmq" # Canonical-Ubuntu-26.04-Minimal-2026.11.05-0
}

variable "alert_webhook_url" {
  description = "Alarm notifications の webhook 先 URL。空の場合はアラーム・トピック・購読を作成しない"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alert_webhook_protocol" {
  description = "webhook の購読プロトコル。CUSTOM_HTTPS は汎用の HTTPS エンドポイント、SLACK は Slack Incoming Webhook"
  type        = string
  default     = "CUSTOM_HTTPS"

  validation {
    condition     = contains(["CUSTOM_HTTPS", "SLACK"], var.alert_webhook_protocol)
    error_message = "alert_webhook_protocol には CUSTOM_HTTPS か SLACK を指定してください。"
  }
}
