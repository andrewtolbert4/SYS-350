output "web_urls" {
  description = "URLs for all web containers"
  value       = [for i in range(var.web_count) : "http://localhost:${var.web_port + i}"]
}

output "container_names" {
  description = "Names of all web containers"
  value       = docker_container.web[*].name
}
