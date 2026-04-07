variable "name" {
  description = "Base name for the microservices deployment."
  type        = string
  default     = "microservices-aca"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "microservices-aca-rg"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "frontend_image" {
  description = "Container image for the frontend app."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "backend_api_image" {
  description = "Container image for the backend API."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "worker_image" {
  description = "Container image for the worker."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "db_connection_string" {
  description = "Database connection string (passed as a secret to backend and worker). Required."
  type        = string
  sensitive   = true
}

variable "frontend_port" {
  description = "Port the frontend container listens on."
  type        = number
  default     = 80
}

variable "backend_api_port" {
  description = "Port the backend API container listens on."
  type        = number
  default     = 80
}

variable "worker_port" {
  description = "Port the worker container listens on (for Dapr)."
  type        = number
  default     = 80
}

variable "frontend_min_replicas" {
  description = "Minimum replicas for the frontend app."
  type        = number
  default     = 1
}

variable "frontend_max_replicas" {
  description = "Maximum replicas for the frontend app."
  type        = number
  default     = 5
}

variable "backend_api_min_replicas" {
  description = "Minimum replicas for the backend API."
  type        = number
  default     = 2
}

variable "backend_api_max_replicas" {
  description = "Maximum replicas for the backend API."
  type        = number
  default     = 10
}

variable "worker_min_replicas" {
  description = "Minimum replicas for the worker."
  type        = number
  default     = 1
}

variable "worker_max_replicas" {
  description = "Maximum replicas for the worker."
  type        = number
  default     = 20
}
