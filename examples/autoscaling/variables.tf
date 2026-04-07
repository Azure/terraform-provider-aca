variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-autoscale"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-10"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "container_image" {
  description = "Container image for both apps."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "http_concurrency_threshold" {
  description = "Number of concurrent HTTP requests per replica before scaling out the web app."
  type        = number
  default     = 50
}

variable "servicebus_namespace" {
  description = "Azure Service Bus namespace for the KEDA scaler (replace with your own)."
  type        = string
  default     = "placeholder-namespace"
}

variable "servicebus_queue_name" {
  description = "Azure Service Bus queue name for the KEDA scaler."
  type        = string
  default     = "orders"
}

variable "servicebus_message_count" {
  description = "Queue message count threshold before scaling out the worker app."
  type        = number
  default     = 5
}
