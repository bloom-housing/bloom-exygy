moved {
  from = aws_prometheus_workspace.bloom
  to   = module.observability.aws_prometheus_workspace.bloom
}

moved {
  from = aws_iam_role.bloom_grafana
  to   = module.observability.aws_iam_role.bloom_grafana
}

moved {
  from = aws_iam_role_policy.bloom_grafana
  to   = module.observability.aws_iam_role_policy.bloom_grafana
}

moved {
  from = aws_grafana_workspace.bloom
  to   = module.observability.aws_grafana_workspace.bloom
}

moved {
  from = aws_grafana_role_association.bloom
  to   = module.observability.aws_grafana_role_association.bloom
}

moved {
  from = grafana_data_source.prometheus
  to   = module.observability.grafana_data_source.prometheus
}

moved {
  from = grafana_dashboard.bloom
  to   = module.observability.grafana_dashboard.bloom
}
