
locals {
  region_account = "${var.bloom_deployment_aws_region}:${var.bloom_deployment_aws_account_number}"

  # The IAM Identity Center permission set inline policy limit is 10,240 non-whitespace characters,
  # and each customer managed policy is limited to 6,144. To stay under both, the deployer's
  # permissions are split into several managed policies grouped by area (see policy_*.tf). Add a new
  # entry here when a group approaches ~5,500 characters rather than growing the inline policy.
  managed_policies = {
    "${var.managed_policy_name_prefix}-console"           = data.aws_iam_policy_document.console.json
    "${var.managed_policy_name_prefix}-network"           = data.aws_iam_policy_document.network.json
    "${var.managed_policy_name_prefix}-compute"           = data.aws_iam_policy_document.compute.json
    "${var.managed_policy_name_prefix}-data-stores"       = data.aws_iam_policy_document.data_stores.json
    "${var.managed_policy_name_prefix}-platform-services" = data.aws_iam_policy_document.platform_services.json
  }
}

# The policies must exist in the deployment account before the permission set is provisioned there.
resource "aws_iam_policy" "deployer" {
  provider = aws.deployment_account
  for_each = local.managed_policies

  name   = each.key
  path   = "/"
  policy = each.value
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "deployer" {
  for_each = local.managed_policies

  instance_arn       = var.iam_identity_center_instance_arn
  permission_set_arn = var.permission_set_arn

  customer_managed_policy_reference {
    name = each.key
    path = "/"
  }

  depends_on = [aws_iam_policy.deployer]
}

# Only the small tofu state policy stays inline. It depends on the attachments so that, when
# migrating from the old single inline policy, permissions are added before they are removed.
resource "aws_ssoadmin_permission_set_inline_policy" "deployer" {
  instance_arn       = var.iam_identity_center_instance_arn
  permission_set_arn = var.permission_set_arn
  inline_policy      = data.aws_iam_policy_document.state.json

  depends_on = [aws_ssoadmin_customer_managed_policy_attachment.deployer]
}


# Create the IAM role for github actions in terraform
# identiy manager policy must have permissions to manipulate roles 
# GetRole, CreateRole, DeleteRole, 
# TagRole, UntagRole, ListRolePolicies
# ListAttachedRolePolicies, ListInstanceProfilesForRole
# iam:AttachRolePolicy, iam:DetachRolePolicy
resource "aws_iam_role" "bloom_terraform_github_actions" {
  provider = aws.deployment_account
  name     = "bloom-terraform-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.bloom_deployment_aws_account_number}:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow the specific repository
            "token.actions.githubusercontent.com:sub" = [
              # Main branch deployments
              "repo:bloom-housing/bloom-exygy:ref:refs/heads/main",
              # Pull request plans
              "repo:bloom-housing/bloom-exygy:pull_request",
            ]
          }
        }
      }
    ]
  })

  # Maximum session duration (1 hour for Terraform runs)
  max_session_duration = 3600

  tags = {
    Purpose = "GitHub Actions Terraform deployments"
  }
}

resource "aws_iam_role_policy_attachment" "bloom_terraform_github_actions_attachment" {
  provider = aws.deployment_account

  depends_on = [aws_iam_policy.deployer]
  for_each   = aws_iam_policy.deployer
  role       = aws_iam_role.bloom_terraform_github_actions.name
  policy_arn = aws_iam_policy.deployer[each.key].arn
}
