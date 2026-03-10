variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-domains"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-9"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "tags" {
  description = "Tags for all resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
    pattern     = "CustomDomains"
  }
}

variable "container_image" {
  description = "Container image for the web app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "custom_domain" {
  description = <<-EOT
    Custom domain to bind to the web app (e.g. "app.example.com").
    Leave empty to skip custom domain binding — the app will deploy
    with only the default ACA domain.
    
    Before setting this value, create DNS records:
      CNAME: <subdomain> → <environment_default_domain>
      TXT:   asuid.<subdomain> → <custom_domain_verification_id>
  EOT
  type        = string
  default     = ""
}
