locals {
  api_default_env_vars = {
    PORT                       = "3100"
    NODE_ENV                   = "production"
    DB_HOST                    = var.aws_rds_address
    DB_PORT                    = "5432"
    DB_USER                    = "bloom_api"
    DB_DATABASE                = "bloom_prisma"
    DB_USE_RDS_IAM_AUTH        = "1"
    USE_AWS_SES                = "1"
    GOOGLE_API_ID              = var.google_translate_settings == null ? "" : var.google_translate_settings.project_id
    GOOGLE_API_EMAIL           = var.google_translate_settings == null ? "" : var.google_translate_settings.iam_user
    S3_REGION                  = var.aws_region
    S3_PRIVATE_BUCKET          = var.aws_s3_private_bucket_id
    S3_PUBLIC_BUCKET           = var.aws_s3_public_bucket_id
    SMS_PROVIDER               = var.bloom_api_sms_config == null ? "" : "aws"
    AWS_SMS_REGION             = var.bloom_api_sms_config == null ? "" : var.aws_region
    AWS_SMS_ORIGINATION_NUMBER = var.bloom_api_sms_config == null ? "" : var.sms_phone_number
  }
}

resource "aws_ecs_service" "bloom_api" {
  wait_for_steady_state         = true # if tofu waits for the triggered deployment to complete.
  region                        = var.aws_region
  cluster                       = var.aws_ecs_cluster_arn
  name                          = "bloom-api"
  force_delete                  = true # allow deletion of the service without scaling down tasks to 0 first.
  task_definition               = aws_ecs_task_definition.bloom_api.arn
  launch_type                   = "FARGATE"
  scheduling_strategy           = "REPLICA"
  availability_zone_rebalancing = "ENABLED"

  lifecycle {
    ignore_changes = [desired_count] # tells terraform to ignore changes to desired_count so it does not fight with the auto scaler
  }

  deployment_configuration {
    strategy = "ROLLING"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    security_groups  = [var.aws_security_group_id]
    subnets          = var.aws_private_subnet_ids
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.aws_service_discovery_http_namespace_arn
    service {
      port_name = "http"
      client_alias {
        dns_name = "bloom-api"
        port     = 3100
      }
      discovery_name = "bloom-api"
      timeout {
        idle_timeout_seconds        = 0 # disable idleTimeout
        per_request_timeout_seconds = 60
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-region"        = var.aws_region
        "awslogs-group"         = var.aws_cloudwatch_log_group_name
        "awslogs-stream-prefix" = "service-connect-proxy"
      }
    }
  }
}

resource "aws_appautoscaling_target" "bloom_api_autoscaling_target" {
  max_capacity       = var.service_task_autoscaling_config.max_tasks
  min_capacity       = var.service_task_autoscaling_config.min_tasks
  resource_id        = "service/${var.aws_ecs_cluster_name}/${aws_ecs_service.bloom_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "bloom_api_appautoscaling_policy_request_cpu" {
  name               = "${aws_ecs_service.bloom_api.name}-cpu-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.bloom_api_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.bloom_api_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.bloom_api_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.service_task_autoscaling_config.cpu_target

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300 # Wait 5 minutes before scaling in
    scale_out_cooldown = 60  # Wait 1 minute before scaling out
  }
}

# Scale based on memory utilization
resource "aws_appautoscaling_policy" "bloom_api_appautoscaling_policy_request_memory" {
  name               = "${aws_ecs_service.bloom_api.name}-memory-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.bloom_api_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.bloom_api_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.bloom_api_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.service_task_autoscaling_config.memory_target

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
