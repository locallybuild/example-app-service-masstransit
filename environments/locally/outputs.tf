output "web_url" {
  description = "Where to reach the web app (place orders) in a browser."
  value       = module.app-service-masstransit.web_url
}

output "worker_url" {
  description = "Where to reach the worker, which hosts the saga and the fulfilment consumer."
  value       = module.app-service-masstransit.worker_url
}

output "servicebus_namespace" {
  description = "The Service Bus namespace MassTransit runs over."
  value       = module.app-service-masstransit.servicebus_namespace
}

output "redis_cache" {
  description = "The Redis cache holding the saga's state."
  value       = module.app-service-masstransit.redis_cache
}
