

locals {
  bloom_deployment = "bloom-dev"
  sso_profile_id   = "${local.bloom_deployment}-iam-admin"

  # Profile with IAM permissions in the bloom deployment account, used to create the customer managed
  # policies the permission set references. Change this if bloom-dev-iam-admin is not a profile for
  # the deployment account.
  deployment_account_sso_profile_id = local.sso_profile_id

  tofu_state_bucket_region = "us-east-1"
  tofu_state_bucket_name   = "bloom-core-tofu-state-files"
  tofu_state_key_prefix    = "${local.bloom_deployment}-deployer-permissionset-policy"

  iam_identity_center_region       = "us-east-1"
  iam_identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-72233fa322bcade3"
  deployer_permission_set_arn      = "arn:aws:sso:::permissionSet/ssoins-72233fa322bcade3/ps-7223cad033e489c7"

  bloom_deployment_aws_account_number     = "242477209009"
  bloom_deployment_aws_region             = "us-west-2"
  bloom_deployment_tofu_state_bucket_name = local.tofu_state_bucket_name
  bloom_deployment_tofu_state_file_prefix = local.bloom_deployment
}



module "deployer_permission_set" {
  source = "git::https://github.com/bloom-housing/bloom.git//infra/tofu_importable_modules/bloom_deployer_permission_set_policy?ref=d39861e4c7f82888a5f1331c9d4577c060e5ca43"

  providers = {
    aws                    = aws
    aws.deployment_account = aws.deployment_account
  }

  iam_identity_center_instance_arn = local.iam_identity_center_instance_arn
  permission_set_arn               = local.deployer_permission_set_arn

  bloom_deployment_aws_account_number     = local.bloom_deployment_aws_account_number
  bloom_deployment_aws_region             = local.bloom_deployment_aws_region
  bloom_deployment_tofu_state_bucket_name = local.bloom_deployment_tofu_state_bucket_name
  bloom_deployment_tofu_state_file_prefix = local.bloom_deployment_tofu_state_file_prefix
}

