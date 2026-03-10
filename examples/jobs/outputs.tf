output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "cleanup_job" {
  description = "Cleanup job details."
  value       = try(module.aca.jobs["cleanup"], null)
}

output "queue_processor_job" {
  description = "Queue processor job details."
  value       = try(module.aca.jobs["queue-processor"], null)
}
