terraform {
  cloud {
    organization = "yumenomatayume"
    workspaces {
      name = "oci"
    }
  }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "5.30.0"
    }
  }
}
