output "lb_dns_name" {
  value       = module.alb.lb_dns_name
  description = "DNS name of the load balancer."
}

output "db_dns_name" {
  value       = module.rds.db_dns_name
  description = "DNS name of the database."
}

output "ses_details" {
  value       = module.ses.ses_details
  description = "Details for the SES email address identity."
}


output "grafana_url" {
  value       = module.observability.grafana_url
  description = "URL of the managed grafana workspace."
}
