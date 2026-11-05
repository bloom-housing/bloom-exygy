resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://tokens.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name        = "github-actions-oidc"
    Description = "OIDC provider for github actions"
  }
}