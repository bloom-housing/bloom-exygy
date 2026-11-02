terraform {
  backend "s3" {
    profile      = local.sso_profile_id
    region       = local.tofu_state_bucket_region
    bucket       = local.tofu_state_bucket_name
    key          = "${local.tofu_state_key_prefix}/state"
    use_lockfile = true
  }
}

provider "aws" {
  profile = local.sso_profile_id
  region  = local.iam_identity_center_region
}

# Account that owns the workloads. The customer managed policies must be created here.
provider "aws" {
  alias   = "deployment_account"
  profile = local.deployment_account_sso_profile_id
  region  = local.bloom_deployment_aws_region
}