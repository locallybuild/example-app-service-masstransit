variable "name_prefix" {
  description = "The prefix used for all resources in this example."
  type        = string
}

variable "location" {
  description = "The region where these resources should be deployed."
  type        = string
}

variable "tags" {
  description = "A mapping of tags which should be applied to each of the resources."
  type        = map(string)
  default     = {}
}

variable "app_service_sku" {
  description = "App Service plan SKU."
  type        = string
  default     = "B1"
}

variable "container_image" {
  description = <<-EOT
    The application image, pulled from Docker Hub and imported into the Locally
    Container Registry. Its source is
    https://github.com/tombuildsstuff/app-service-masstransit.

    The default is a multi-arch build carrying both linux/amd64 (Azure App
    Service) and linux/arm64 (Apple Silicon), so it runs on either.
  EOT
  type        = string
  default     = "docker.io/tombuildsstuff/app-service-masstransit:v1.0.0"
}

variable "redis_authentication" {
  description = <<-EOT
    How the apps sign in to Azure Cache for Redis:

      * "entra"      - as each app's managed identity, with access keys
        disabled on the cache.
      * "access-key" - with the cache's primary access key, passed as an app
        setting.
  EOT
  type        = string
  default     = "entra"

  validation {
    condition     = contains(["access-key", "entra"], var.redis_authentication)
    error_message = "redis_authentication must be either \"access-key\" or \"entra\"."
  }
}
