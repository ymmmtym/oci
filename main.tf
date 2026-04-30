terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
      version = "5.30.0"
    }
  }
}

provider "oci" {
  tenancy_ocid          = var.tenancy_ocid
  user_ocid             = var.user_ocid
  fingerprint           = var.fingerprint
  private_key           = var.private_key
  region                = var.region
}

data "oci_identity_availability_domains" "ad" {
    #Required
    compartment_id = var.tenancy_ocid
}

# VCNの作成
resource "oci_core_vcn" "free_tier_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.tenancy_ocid
  display_name   = "free-tier-vcn"
  dns_label      = "freetier"
}

# パブリックサブネットの作成
resource "oci_core_subnet" "public_subnet" {
  cidr_block          = "10.0.1.0/24"
  display_name        = "public-subnet"
  compartment_id      = var.tenancy_ocid
  vcn_id              = oci_core_vcn.free_tier_vcn.id
  route_table_id      = oci_core_route_table.public_rt.id
  security_list_ids   = [oci_core_security_list.public_sl.id]
  prohibit_public_ip_on_vnic = false
}

# プライベートサブネットの作成
resource "oci_core_subnet" "private_subnet" {
  cidr_block          = "10.0.2.0/24"
  display_name        = "private-subnet"
  compartment_id      = var.tenancy_ocid
  vcn_id              = oci_core_vcn.free_tier_vcn.id
  prohibit_public_ip_on_vnic = true
}

# Internet Gatewayの作成
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.tenancy_ocid
  display_name   = "free-tier-igw"
  vcn_id         = oci_core_vcn.free_tier_vcn.id
}

# ルートテーブル - パブリック
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.free_tier_vcn.id
  display_name   = "public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# セキュリティグループ - パブリック
resource "oci_core_security_list" "public_sl" {
  compartment_id = var.tenancy_ocid
  display_name   = "public-security-list"
  vcn_id         = oci_core_vcn.free_tier_vcn.id

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
  vcn_id         = oci_core_vcn.free_tier_vcn.id

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
resource "oci_objectstorage_bucket" "free_tier_bucket" {
  compartment_id = var.tenancy_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "free-tier-bucket"
  access_type    = "NoPublicAccess"
}

output "list_ads" {
  value = data.oci_identity_availability_domains.ad.availability_domains
}

output "bucket_namespace" {
  value = data.oci_objectstorage_namespace.ns.namespace
}

output "bucket_name" {
  value = oci_objectstorage_bucket.free_tier_bucket.name
}

# Compute Instances (Always Free - VM.Standard.E2.1.Micro x2)
resource "oci_core_instance" "free_tier_micro" {
  count               = 2
  availability_domain = data.oci_identity_availability_domains.ad.availability_domains[0].name
  compartment_id      = var.tenancy_ocid
  display_name        = "free-tier-micro-${count.index + 1}"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.ap-osaka-1.aaaaaaaayfht7uc4cx7tqjtjtdkbo6n7oyu2m2qtummtwb5c57co7v2uvzia"
  }

  metadata = {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/TAlBnd+IVdqIanbmgMppxclaWTg8dw0ncXnNMqjAxaAHDF/MsEjSJlG9CtfFzqouNZqNh5wd71lZ1e+cBbww1FKGPnNmOSReJq49Mjo6tyZwnUOUyiKMpChQlYJSRsX92ry9DHlF4KKX4tdP82pShEkSR7pxj+14cFAMs+IOB8oQi8KY8nPRuIGCIXZXiEjfP4QaSA1iXO2dhR2yvw93c5mIi4hASJR0SlqI+iy51nYc9fWFEjn64Ms0J08hxXslj/kjaBfrF46uoduA6se9wKNJ90m4s3+pB1Fcpd42S6JGOYQqY+gaw+fGPJmmK0hbH7yXIbePgAkv9LJhy7laoMt7Q6cdmEOzYPvvshOp1OpOHmqNN/K2Kvwco5/pnmgI9RHNdgulJrP//qcz+q3Uh7u++q+MstaWD5dBuqiSM5QWwDMvqiYysn0J9Jhh43wVCfg9F6DFhg8rSvavuGW4xaaQmSFc7FgY4RWfE+D5LsA3p2IYLg9XfQJSuxAOJEPgmFs7swmiH5pkgi69pWIJ5U00Ul1MrbfET4ErzECDa/603K2nzpGPiH+ZsimWA6NXZAR/AgtWB9OCcYJBR5BiQFjS8oLwjy30MHio5OLLzq5qg69Idkl5frzowkhHyJHJLCNeu0kmsrTBpXEUUqJOtC7k6aQabl+5+Tu6z80x/w== yukihisa@mac-mini.yumenomatayume.home"
  }
}

output "instance_public_ips" {
  value = oci_core_instance.free_tier_micro[*].public_ip
}

# Ampere A1 Instance (Always Free - 4 OCPU, 24GB RAM)
# NOTE: ap-osaka-1リージョンではキャパシティ不足のため作成できず (2026-04-30)
# resource "oci_core_instance" "free_tier_ampere" {
#   availability_domain = data.oci_identity_availability_domains.ad.availability_domains[0].name
#   compartment_id      = var.tenancy_ocid
#   display_name        = "free-tier-ampere-a1"
#   shape               = "VM.Standard.A1.Flex"
#
#   shape_config {
#     ocpus         = 4
#     memory_in_gbs = 24
#   }
#
#   create_vnic_details {
#     subnet_id        = oci_core_subnet.public_subnet.id
#     assign_public_ip = true
#   }
#
#   source_details {
#     source_type = "image"
#     source_id   = "ocid1.image.oc1.ap-osaka-1.aaaaaaaa7g7qc6hssaqwodi5saxziwpdn3qwm35ulvbjch2qniiusiq76yaq"
#   }
#
#   metadata = {
#     ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/TAlBnd+IVdqIanbmgMppxclaWTg8dw0ncXnNMqjAxaAHDF/MsEjSJlG9CtfFzqouNZqNh5wd71lZ1e+cBbww1FKGPnNmOSReJq49Mjo6tyZwnUOUyiKMpChQlYJSRsX92ry9DHlF4KKX4tdP82pShEkSR7pxj+14cFAMs+IOB8oQi8KY8nPRuIGCIXZXiEjfP4QaSA1iXO2dhR2yvw93c5mIi4hASJR0SlqI+iy51nYc9fWFEjn64Ms0J08hxXslj/kjaBfrF46uoduA6se9wKNJ90m4s3+pB1Fcpd42S6JGOYQqY+gaw+fGPJmmK0hbH7yXIbePgAkv9LJhy7laoMt7Q6cdmEOzYPvvshOp1OpOHmqNN/K2Kvwco5/pnmgI9RHNdgulJrP//qcz+q3Uh7u++q+MstaWD5dBuqiSM5QWwDMvqiYysn0J9Jhh43wVCfg9F6DFhg8rSvavuGW4xaaQmSFc7FgY4RWfE+D5LsA3p2IYLg9XfQJSuxAOJEPgmFs7swmiH5pkgi69pWIJ5U00Ul1MrbfET4ErzECDa/603K2nzpGPiH+ZsimWA6NXZAR/AgtWB9OCcYJBR5BiQFjS8oLwjy30MHio5OLLzq5qg69Idkl5frzowkhHyJHJLCNeu0kmsrTBpXEUUqJOtC7k6aQabl+5+Tu6z80x/w== yukihisa@mac-mini.yumenomatayume.home"
#   }
# }
#
# output "ampere_public_ip" {
#   value = oci_core_instance.free_tier_ampere.public_ip
# }
