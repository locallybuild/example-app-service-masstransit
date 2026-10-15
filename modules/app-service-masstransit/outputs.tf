output "web_url" {
  description = "Where to reach the web app (place orders) in a browser."
  value       = "https://${azurerm_linux_web_app.main["web"].default_hostname}"
}

output "worker_url" {
  description = "Where to reach the worker, which hosts the saga and the fulfilment consumer."
  value       = "https://${azurerm_linux_web_app.main["worker"].default_hostname}"
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = azurerm_resource_group.main.name
}

output "servicebus_namespace" {
  description = "The Service Bus namespace MassTransit runs over."
  value       = azurerm_servicebus_namespace.main.name
}

output "redis_cache" {
  description = "The Redis cache holding the saga's state."
  value       = azurerm_redis_cache.main.name
}
