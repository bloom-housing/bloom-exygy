output "grafana_url" {
  value       = "https://${aws_grafana_workspace.bloom.endpoint}"
  description = "URL of the managed grafana workspace."
}

output "aws_prometheus_workspace_arn" {
  value = aws_prometheus_workspace.bloom.arn
}

output "otel_sidecar_container" {
  value = local.otel_sidecar_container
}

output "otel_env_vars" {
  value = local.otel_env_vars
}
