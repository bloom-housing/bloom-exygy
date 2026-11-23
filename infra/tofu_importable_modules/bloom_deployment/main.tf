locals {
  is_prod                 = var.env_type == "production"
  ecs_logs_retention_days = var.ecs_logs_retention_days != null ? var.ecs_logs_retention_days : (local.is_prod ? 30 : 3)
}

# Create a CloudTrail data store so that audit events are query-able in SQL.
resource "aws_cloudtrail_event_data_store" "audit" {
  count = local.is_prod ? 1 : 0

  region                         = var.aws_region
  name                           = "audit"
  multi_region_enabled           = true
  retention_period               = 30
  termination_protection_enabled = true
}

module "alb" {
  source = "./alb"

  aws_certificate_arn   = var.aws_certificate_arn
  aws_vpc_id            = module.vpc.aws_vpc_id
  aws_public_subnet_ids = module.vpc.aws_public_subnet_ids
  aws_security_group_id = [module.vpc.aws_security_groups["lb"]]

  aws_region  = var.aws_region
  domain_name = var.domain_name
}

module "ecs_cluster" {
  source = "./ecs_cluster"

  aws_account_number = var.aws_account_number
  aws_profile        = var.aws_profile
  aws_region         = var.aws_region

  aws_db_master_user_secret = module.rds.master_user_secret
  aws_db_instance_id        = module.rds.aws_db_instance_id

  aws_prometheus_workspace_arn = module.observability.aws_prometheus_workspace_arn

  bloom_dbseed_image = var.bloom_dbseed_image

  ecs_logs_retention_days = local.ecs_logs_retention_days


  secretsmanager_api_jwt_signing_key_arn      = module.secretsmanager.api_key_secret_arns["api_jwt_signing_key"]
  secretsmanager_mapbox_api_key_arn           = module.secretsmanager.api_key_secret_arns["mapbox_api_key"]
  secretsmanager_google_translate_api_key_arn = module.secretsmanager.api_key_secret_arns["google_translate_api_key"]
}

module "ecs_api_service" {
  depends_on = [
    module.rds,
    module.vpc.aws_vpc_secrets_manager_endpoint,
    module.vpc.aws_route_table_association_private_subnet,
    module.ecs_dbinit_task,
  ]

  source = "./ecs_services/ecs_api_service"

  bloom_api_image    = var.bloom_api_image
  bloom_api_env_vars = var.bloom_api_env_vars

  aws_region = var.aws_region

  aws_ecs_cluster_name = module.ecs_cluster.cluster_name
  aws_ecs_cluster_arn  = module.ecs_cluster.arn

  aws_rds_address = module.rds.aws_db_address

  aws_s3_private_bucket_id = module.s3.private_bucket_id
  aws_s3_public_bucket_id  = module.s3.public_bucket_id

  aws_iam_role_bloom_ecs_arn       = module.ecs_cluster.aws_iam_role_bloom_ecs_arns["api"]
  aws_iam_role_bloom_container_arn = module.ecs_cluster.aws_iam_role_bloom_container_arns["api"]

  aws_cloudwatch_log_group_name = module.ecs_cluster.aws_task_log_group_names["bloom-api"]

  aws_private_subnet_ids = module.vpc.aws_private_subnet_ids
  aws_security_group_id  = module.vpc.aws_security_groups["api"]

  google_translate_settings = var.google_translate_settings


  aws_service_discovery_http_namespace_arn = module.ecs_cluster.aws_service_discovery_http_namespace_arn

  # otel_sidecar_container = []
  # otel_sidecar_env_vars  = {}

  resource_limits = {
    vcpu       = var.bloom_api_resource_limits.vcpu
    memory_mib = var.bloom_api_resource_limits.memory_mib
  }

  service_task_autoscaling_config = {
    cpu_target    = var.service_task_autoscaling_config.cpu_target
    memory_target = var.service_task_autoscaling_config.memory_target

    min_tasks = var.service_task_autoscaling_config.api_service_min_tasks
    max_tasks = var.service_task_autoscaling_config.api_service_max_tasks
  }

  bloom_api_sms_config = var.bloom_api_sms_config
  sms_phone_number     = module.sms.sms_phone_number

  secretsmanager_api_jwt_signing_key_arn      = module.secretsmanager.api_key_secret_arns["api_jwt_signing_key"]
  secretsmanager_google_translate_api_key_arn = module.secretsmanager.api_key_secret_arns["google_translate_api_key"]
}

module "ecs_site_partners_service" {
  depends_on = [
    module.ecs_api_service,
    module.vpc.aws_route_table_association_private_subnet,
    module.ecs_dbseed_task,
  ]

  source = "./ecs_services/ecs_site_partners_service"

  image = var.bloom_site_partners_image

  aws_region          = var.aws_region
  aws_ecs_cluster_arn = module.ecs_cluster.arn

  aws_ecs_cluster_name = module.ecs_cluster.cluster_name

  aws_iam_role_bloom_ecs_arn       = module.ecs_cluster.aws_iam_role_bloom_ecs_arns["site-partners"]
  aws_iam_role_bloom_container_arn = module.ecs_cluster.aws_iam_role_bloom_container_arns["site-partners"]

  aws_cloudwatch_log_group_name = module.ecs_cluster.aws_task_log_group_names["bloom-site-partners"]

  aws_private_subnet_ids = module.vpc.aws_private_subnet_ids
  aws_security_group_id  = module.vpc.aws_security_groups["site-partners"]

  env_vars = var.bloom_site_partners_env_vars

  aws_service_discovery_http_namespace_arn = module.ecs_cluster.aws_service_discovery_http_namespace_arn

  # otel_sidecar_container = []
  # otel_sidecar_env_vars  = {}

  aws_lb_target_group_site_partners_arn = module.alb.aws_lb_target_group_site_partners_arn

  resource_limits = {
    vcpu       = var.bloom_site_partners_resource_limits.vcpu
    memory_mib = var.bloom_site_partners_resource_limits.memory_mib
  }

  service_task_autoscaling_config = {
    cpu_target    = var.service_task_autoscaling_config.cpu_target
    memory_target = var.service_task_autoscaling_config.memory_target

    min_tasks = var.service_task_autoscaling_config.partners_service_min_tasks
    max_tasks = var.service_task_autoscaling_config.partners_service_max_tasks
  }

  secretsmanager_mapbox_api_key_arn = module.secretsmanager.api_key_secret_arns["mapbox_api_key"]
}


module "ecs_site_public_service" {
  depends_on = [
    module.ecs_api_service,
    module.vpc.aws_route_table_association_private_subnet,
    module.ecs_dbseed_task
  ]

  source = "./ecs_services/ecs_site_public_service"

  image = var.bloom_site_public_image

  aws_region          = var.aws_region
  aws_ecs_cluster_arn = module.ecs_cluster.arn

  aws_ecs_cluster_name = module.ecs_cluster.cluster_name

  aws_iam_role_bloom_ecs_arn       = module.ecs_cluster.aws_iam_role_bloom_ecs_arns["site-public"]
  aws_iam_role_bloom_container_arn = module.ecs_cluster.aws_iam_role_bloom_container_arns["site-public"]

  aws_cloudwatch_log_group_name = module.ecs_cluster.aws_task_log_group_names["bloom-site-public"]

  aws_private_subnet_ids = module.vpc.aws_private_subnet_ids
  aws_security_group_id  = module.vpc.aws_security_groups["site-public"]

  env_vars = var.bloom_site_public_env_vars

  aws_service_discovery_http_namespace_arn = module.ecs_cluster.aws_service_discovery_http_namespace_arn

  # otel_sidecar_container = []
  # otel_sidecar_env_vars  = {}

  aws_lb_target_group_site_public_arn = module.alb.aws_lb_target_group_site_public_arn

  resource_limits = {
    vcpu       = var.bloom_site_public_resource_limits.vcpu
    memory_mib = var.bloom_site_public_resource_limits.memory_mib
  }

  service_task_autoscaling_config = {
    cpu_target    = var.service_task_autoscaling_config.cpu_target
    memory_target = var.service_task_autoscaling_config.memory_target

    min_tasks = var.service_task_autoscaling_config.public_service_min_tasks
    max_tasks = var.service_task_autoscaling_config.public_service_max_tasks
  }

  secretsmanager_mapbox_api_key_arn = module.secretsmanager.api_key_secret_arns["mapbox_api_key"]
}

resource "time_sleep" "on_dbinit_container_role_creation" {
  depends_on = [
    module.ecs_cluster
  ]
  create_duration = "30s"
}

module "ecs_dbinit_task" {
  depends_on = [
    time_sleep.on_dbinit_container_role_creation,
    module.vpc.aws_vpc_secrets_manager_endpoint,
    module.vpc.aws_route_table_private_subnet,
  ]

  source = "./ecs_tasks/ecs_dbinit_task"

  aws_profile         = var.aws_profile
  aws_region          = var.aws_region
  aws_ecs_cluster_arn = module.ecs_cluster.arn

  aws_db_address            = module.rds.aws_db_address
  aws_db_instance_id        = module.rds.aws_db_instance_id
  aws_db_master_username    = module.rds.master_username
  aws_db_master_user_secret = module.rds.master_user_secret

  aws_iam_role_bloom_ecs_arn       = module.ecs_cluster.aws_iam_role_bloom_ecs_arns["dbinit"]
  aws_iam_role_bloom_container_arn = module.ecs_cluster.aws_iam_role_bloom_container_arns["dbinit"]

  aws_cloudwatch_log_group_name = module.ecs_cluster.aws_task_log_group_names["bloom-dbinit"]

  aws_private_subnet_ids = module.vpc.aws_private_subnet_ids
  aws_security_group_id  = module.vpc.aws_security_groups["dbinit"]

  bloom_dbinit_run_number = var.bloom_dbinit_run_number
  bloom_dbinit_image      = var.bloom_dbinit_image
}

# Avoids the error:
#
# module.bloom_deployment.null_resource.bloom_dbseed_run (local-exec): An error occurred
# (ClientException) when calling the RunTask operation: ECS was unable to assume the role
# 'arn:aws:iam::x:role/bloom-dbseed-container' that was provided for this task.
resource "time_sleep" "on_dbseed_container_role_creation" {
  count = var.bloom_dbseed_image == "" ? 0 : 1

  depends_on = [
    module.ecs_cluster
  ]

  create_duration = "30s"
}

module "ecs_dbseed_task" {
  depends_on = [
    module.vpc.aws_vpc_secrets_manager_endpoint,
    module.vpc.aws_route_table_association_private_subnet,
    time_sleep.on_dbseed_container_role_creation,
    module.ecs_dbinit_task,
    module.ecs_api_service, # need API to apply migrations before seed can run.
  ]

  source = "./ecs_tasks/ecs_dbseed_task"

  aws_profile         = var.aws_profile
  aws_region          = var.aws_region
  aws_ecs_cluster_arn = module.ecs_cluster.arn

  aws_db_address     = module.rds.aws_db_address
  aws_db_instance_id = module.rds.aws_db_instance_id

  aws_iam_role_bloom_ecs_arn       = module.ecs_cluster.aws_iam_role_bloom_ecs_arns["dbseed"]
  aws_iam_role_bloom_container_arn = module.ecs_cluster.aws_iam_role_bloom_container_arns["dbseed"]

  aws_cloudwatch_log_group_name = module.ecs_cluster.aws_task_log_group_names["bloom-dbseed"]

  aws_private_subnet_ids = module.vpc.aws_private_subnet_ids
  aws_security_group_id  = module.vpc.aws_security_groups["dbseed"]

  bloom_dbseed_run_number = var.bloom_dbseed_run_number
  bloom_dbseed_image      = var.bloom_dbseed_image

  domain_name = var.domain_name
}

module "observability" {
  source = "./observability"

  aws_profile        = var.aws_profile
  aws_account_number = var.aws_account_number
  aws_region         = var.aws_region

  aws_cloudwatch_log_group_name = module.ecs_cluster.aws_task_log_group_names["bloom-api"]

  bloom_otel_collector_image = var.bloom_otel_collector_image

  grafana_editor_group_ids = var.grafana_editor_group_ids

  observability_collection_enabled = var.observability_collection_enabled
}

module "rds" {
  source = "./rds"

  aws_region                     = var.aws_region
  aws_private_subnet_ids         = module.vpc.aws_private_subnet_ids
  aws_security_group_bloom_db_id = module.vpc.aws_security_groups["db"]

  database_config = local.database_config

  is_prod = local.is_prod
}

module "s3" {
  source = "./s3"

  aws_region = var.aws_region

  bloom_api_container_iam_role_arn = module.ecs_cluster.aws_iam_role_bloom_container_arns["api"]

  domain_name = var.domain_name
  is_prod     = local.is_prod
}

module "secretsmanager" {
  source = "./secretsmanager"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region
}

module "ses" {
  source = "./ses"

  aws_region     = var.aws_region
  ses_identities = var.ses_identities
}

module "sms" {
  source = "./sms"

  aws_region           = var.aws_region
  bloom_api_sms_config = var.bloom_api_sms_config
}

module "vpc" {
  source = "./vpc"

  aws_region         = var.aws_region
  bloom_dbseed_image = var.bloom_dbseed_image

  vpc_cidr_range       = var.vpc_cidr_range
  vpc_peering_settings = var.vpc_peering_settings
}
