resource "aws_iam_role" "tofu_github_actions" {
  name = "tofu-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow the specific repo
            "token.actions.githubusercontent.com:sub" = [
              "repo:bloom-housing/bloom-exygy:ref:refs/heads/main"
            ]
          }
        }
      }
    ]
  })

  # 1 hour for tofu runs
  max_session_duration = 3600

  tags = {
    Purpose = "Github Actions Tofu Deployments"
  }
}

resource "aws_iam_role_policy" "tofu_permissions" {
  name = "tofu-permissions"
  role = aws_iam_role.tofu_github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "s3:*",
          "iam:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
        ]
        Resource = "*"
      },
      {
        # Allow tofu to manage it's own state in s3
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::bloom-core-tofu-state-files",
          "arn:aws:s3:::bloom-core-tofu-state-files/*",
        ]
      },
      {
        # Allow State locking with DynamoDB
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:123456789012:table/terraform-locks"
      }
    ]
  })
}