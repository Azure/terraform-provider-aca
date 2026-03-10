variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-java"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-14"
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
  }
}

variable "container_image" {
  description = "Container image for the Java Spring Boot application."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "enable_config_server" {
  description = "Whether to create a Spring Cloud Config Server component."
  type        = bool
  default     = true
}

variable "config_git_uri" {
  description = "Git repository URI for the Spring Cloud Config Server."
  type        = string
  default     = "https://github.com/spring-cloud-samples/config-repo"
}
