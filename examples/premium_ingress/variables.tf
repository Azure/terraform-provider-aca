variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-premium-ingress"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-16"
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
    pattern     = "PremiumIngress"
  }
}

variable "container_image" {
  description = "Container image for the API app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

# ---------------------------------------------------------------------------
# Premium Ingress settings
# ---------------------------------------------------------------------------

variable "ingress_profile_name" {
  description = "Name of the dedicated ingress workload profile."
  type        = string
  default     = "premium-ingress"
}

variable "ingress_profile_type" {
  description = "Workload profile SKU for ingress (D4, D8, D16, D32)."
  type        = string
  default     = "D4"
}

variable "ingress_min_nodes" {
  description = "Minimum number of ingress nodes."
  type        = number
  default     = 2
}

variable "ingress_max_nodes" {
  description = "Maximum number of ingress nodes."
  type        = number
  default     = 10
}

variable "termination_grace_period_minutes" {
  description = "Termination grace period in minutes (null = backend default)."
  type        = number
  default     = null
}

variable "request_idle_timeout" {
  description = "Request idle timeout in minutes (null = backend default)."
  type        = number
  default     = null
}

variable "header_count_limit" {
  description = "Maximum HTTP headers per request (null = backend default)."
  type        = number
  default     = null
}
