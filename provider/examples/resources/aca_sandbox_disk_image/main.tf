terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aca = {
      source = "Azure/aca"
    }
  }
}

variable "sandbox_group_id" {
  type = string
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "image" {
  description = "Digest-pinned container image reference."
  type        = string
}

variable "pull_identity_client_id" {
  type = string
}

provider "aca" {
  use_azure_cli = true
}

resource "aca_sandbox_disk_image" "example" {
  sandbox_group_id = var.sandbox_group_id
  location         = var.location
  name             = "native-provider-image"
  base_image       = var.image

  managed_identity_client_id = var.pull_identity_client_id
  deletion_policy            = "Retain"

  lifecycle {
    prevent_destroy = true
  }
}

output "disk_image_id" {
  value = aca_sandbox_disk_image.example.id
}

output "import_url" {
  value = aca_sandbox_disk_image.example.resource_url
}
