resource "aws_iam_role" "bloom_grafana" {
  name        = "bloom-grafana"
  description = "Role the Bloom managed Grafana workspace uses."
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "grafana.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "bloom_grafana" {
  name = "bloom-grafana"
  role = aws_iam_role.bloom_grafana.id
  # From 'Amazon Managed Service for Prometheus' section in
  # https://docs.aws.amazon.com/grafana/latest/userguide/AMG-manage-permissions.html:
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:aps:${var.aws_region}:${var.aws_account_number}:/workspaces", # for the ListWorkspaces permission.
          aws_prometheus_workspace.bloom.arn,
        ]
      },
    ]
  })
}

resource "aws_grafana_role_association" "bloom" {
  workspace_id = aws_grafana_workspace.bloom.id
  role         = "EDITOR"
  group_ids    = var.grafana_editor_group_ids
}
