provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key
  region       = var.region
}

locals {
  tags = {
    "managed-by" = "terraform"
  }
}

data "oci_identity_availability_domains" "ad" {
  #Required
  compartment_id = var.tenancy_ocid
}

# VCNの作成
resource "oci_core_vcn" "vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.tenancy_ocid
  display_name   = "vcn"
  dns_label      = "vcn"
  freeform_tags  = local.tags
}

# パブリックサブネットの作成
resource "oci_core_subnet" "public_subnet" {
  cidr_block                 = "10.0.1.0/24"
  display_name               = "public-subnet"
  dns_label                  = "public"
  compartment_id             = var.tenancy_ocid
  vcn_id                     = oci_core_vcn.vcn.id
  route_table_id             = oci_core_route_table.public_rt.id
  security_list_ids          = [oci_core_security_list.public_sl.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.tags
}

# プライベートサブネットの作成
resource "oci_core_subnet" "private_subnet" {
  cidr_block                 = "10.0.2.0/24"
  display_name               = "private-subnet"
  dns_label                  = "private"
  compartment_id             = var.tenancy_ocid
  vcn_id                     = oci_core_vcn.vcn.id
  route_table_id             = oci_core_route_table.private_rt.id
  security_list_ids          = [oci_core_security_list.private_sl.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.tags
}

# Internet Gatewayの作成
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.tenancy_ocid
  display_name   = "igw"
  vcn_id         = oci_core_vcn.vcn.id
  freeform_tags  = local.tags
}

# ルートテーブル - パブリック
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "public-rt"
  freeform_tags  = local.tags

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# ルートテーブル - プライベート
resource "oci_core_route_table" "private_rt" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "private-rt"
  freeform_tags  = local.tags
}

# セキュリティグループ - パブリック
resource "oci_core_security_list" "public_sl" {
  compartment_id = var.tenancy_ocid
  display_name   = "public-security-list"
  vcn_id         = oci_core_vcn.vcn.id
  freeform_tags  = local.tags

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
}

# セキュリティグループ - プライベート
resource "oci_core_security_list" "private_sl" {
  compartment_id = var.tenancy_ocid
  display_name   = "private-security-list"
  vcn_id         = oci_core_vcn.vcn.id
  freeform_tags  = local.tags

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "10.0.0.0/16"
    tcp_options {
      min = 22
      max = 22
    }
  }
}

# Object Storage Namespace (データソース)
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

# Object Storage Bucket (Always Free - 20GB)
resource "oci_objectstorage_bucket" "bucket" {
  compartment_id = var.tenancy_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "bucket"
  access_type    = "NoPublicAccess"
  freeform_tags  = local.tags
}

output "list_ads" {
  value = data.oci_identity_availability_domains.ad.availability_domains
}

output "bucket_namespace" {
  value = data.oci_objectstorage_namespace.ns.namespace
}

output "bucket_name" {
  value = oci_objectstorage_bucket.bucket.name
}

# Compute Instances (Always Free - VM.Standard.E2.1.Micro x2)
resource "oci_core_instance" "micro" {
  count               = 2
  availability_domain = data.oci_identity_availability_domains.ad.availability_domains[count.index % length(data.oci_identity_availability_domains.ad.availability_domains)].name
  compartment_id      = var.tenancy_ocid
  display_name        = format("jp-bastion-%02d", count.index + 1)
  shape               = "VM.Standard.E2.1.Micro"
  freeform_tags       = local.tags

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = format("jp-bastion-%02d", count.index + 1)
  }

  source_details {
    source_type = "image"
    source_id   = var.ubuntu_image_ocid
  }

  metadata = {
    ssh_authorized_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBt4FxKvmGV9kGLPox96alMMYUrwNuyVNJ9Vd040qfr ubuntu@oci"

    user_data = base64encode(join("\n", [
      "#cloud-config",
      yamlencode({
        package_update             = true
        package_upgrade            = true
        package_reboot_if_required = true

        packages = [
          "git",
          "curl",
          "tar",
          "ca-certificates",
          "libatomic1",
        ]

        ssh_pwauth   = false
        disable_root = true

        swap = {
          filename = "/swap"
          size     = 2147483648
          maxsize  = 2147483648
        }
      })
    ]))
  }
}

output "instance_public_ips" {
  value = oci_core_instance.micro[*].public_ip
}

output "instance_fqdns" {
  value = [
    for i in oci_core_instance.micro :
    format("%s.%s.%s.oraclevcn.com", i.create_vnic_details[0].hostname_label, oci_core_subnet.public_subnet.dns_label, oci_core_vcn.vcn.dns_label)
  ]
}

# Autonomous Database Lite (Always Free - 1 ECPU + 20GB)
resource "oci_database_autonomous_database" "adb" {
  compartment_id = var.tenancy_ocid
  db_name        = "adb"
  admin_password = var.adb_admin_password
  compute_model  = "ECPU"
  compute_count  = 1
  db_workload    = "OLTP"
  is_free_tier   = true
  display_name   = "adb-lite"
  freeform_tags  = local.tags
}

output "adb_connection_strings" {
  value     = oci_database_autonomous_database.adb.connection_strings
  sensitive = true
}

# # Ampere A1 Instance (Always Free - 2 OCPU, 12GB RAM)
# data "oci_core_images" "ampere_os_image" {
#   compartment_id           = var.tenancy_ocid
#   operating_system         = "Canonical Ubuntu"
#   operating_system_version = "22.04"
#   shape                    = "VM.Standard.A1.Flex"
#   sort_by                  = "TIMECREATED"
#   sort_order               = "DESC"
# }
# 
# resource "oci_core_instance" "ampere" {
#   availability_domain = data.oci_identity_availability_domains.ad.availability_domains[0].name
#   compartment_id      = var.tenancy_ocid
#   display_name        = "ampere-a1"
#   shape               = "VM.Standard.A1.Flex"
# 
#   shape_config {
#     ocpus         = 2
#     memory_in_gbs = 12
#   }
# 
#   create_vnic_details {
#     subnet_id        = oci_core_subnet.public_subnet.id
#     assign_public_ip = true
#   }
# 
#   source_details {
#     source_type = "image"
#     source_id   = data.oci_core_images.ampere_os_image.images[0].id
#   }
# 
#   metadata = {
#     ssh_authorized_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBt4FxKvmGV9kGLPox96alMMYUrwNuyVNJ9Vd040qfr ubuntu@oci" 
#   }
# }
# 
# output "ampere_public_ip" {
#   value = oci_core_instance.ampere.public_ip
# }
