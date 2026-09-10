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

provider "aca" {
  use_azure_cli = true
}

data "aca_sandbox_public_disk_image" "ubuntu" {
  sandbox_group_id = var.sandbox_group_id
  location         = var.location
  name             = "ubuntu"
}

resource "aca_sandbox" "example" {
  sandbox_group_id = var.sandbox_group_id
  location         = var.location
  name             = "native-provider-example"

  source = {
    public_disk_image = data.aca_sandbox_public_disk_image.ubuntu.name
  }

  resources = {
    cpu    = "1000m"
    memory = "2048Mi"
  }

  auto_suspend = {
    enabled          = true
    interval_seconds = 300
    mode             = "Memory"
  }

  egress_policy = {
    default_action = "Deny"
  }

  ports = {
    web = {
      port     = 8080
      protocol = "Http"
      auth = {
        anonymous = false
      }
    }
  }

  deletion_policy = "Retain"

  lifecycle {
    prevent_destroy = true
  }
}

output "sandbox_id" {
  value = aca_sandbox.example.id
}

output "sandbox_url" {
  value     = aca_sandbox.example.ports["web"].url
  sensitive = true
}
