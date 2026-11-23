locals {
  site_public_default_env_vars = {
    NODE_ENV                      = "production"
    DISABLE_NEXT_TYPECHECK        = "TRUE"
    NEXTJS_PORT                   = "3000"
    BACKEND_API_BASE              = "http://bloom-api:3100"
    BACKEND_API_BASE_NEW          = "http://bloom-api:3100"
    LISTINGS_QUERY                = "/listings"
    MAX_BROWSE_LISTINGS           = "10"
    HOUSING_COUNSELOR_SERVICE_URL = "/get-assistance"
    IDLE_TIMEOUT                  = "5"  # seconds
    CACHE_REVALIDATE              = "30" # seconds
    SHOW_PUBLIC_LOTTERY           = "TRUE"
    SHOW_MANDATED_ACCOUNTS        = "FALSE"
    SHOW_PWDLESS                  = "FALSE"
    SHOW_NEW_SEEDS_DESIGNS        = "TRUE"
    NON_PROD_BANNER               = "FALSE"
  }
}

resource "aws_ecs_service" "bloom_site_public" {
  region                = var.aws_region
  cluster               = var.aws_ecs_cluster_arn
  name                  = "bloom-site-public"
  force_delete          = true # allow deletion of the service without scaling down tasks to 0 first.
  task_definition       = aws_ecs_task_definition.bloom_site_public.arn
  wait_for_steady_state = true
  desired_count         = var.service_task_autoscaling_config.min_tasks

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
    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-region"        = var.aws_region
        "awslogs-group"         = var.aws_cloudwatch_log_group_name
        "awslogs-stream-prefix" = "service-connect-proxy"
      }
    }
  }

  load_balancer {
    target_group_arn = var.aws_lb_target_group_site_public_arn
    container_name   = "bloom-site-public"
    container_port   = 3000
  }
  health_check_grace_period_seconds = 500 # seconds, how long the LB will wait before considering a new task unhealthy.

  launch_type                   = "FARGATE"
  scheduling_strategy           = "REPLICA"
  availability_zone_rebalancing = "ENABLED"
}


resource "aws_appautoscaling_target" "bloom_site_public_autoscaling_target" {
  max_capacity       = var.service_task_autoscaling_config.max_tasks
  min_capacity       = var.service_task_autoscaling_config.min_tasks
  resource_id        = "service/${var.aws_ecs_cluster_name}/${aws_ecs_service.bloom_site_public.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "bloom_site_public_appautoscaling_policy_request_cpu" {
  name               = "${aws_ecs_service.bloom_site_public.name}-cpu-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.bloom_site_public_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.bloom_site_public_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.bloom_site_public_autoscaling_target.service_namespace

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
resource "aws_appautoscaling_policy" "bloom_site_public_appautoscaling_policy_request_memory" {
  name               = "${aws_ecs_service.bloom_site_public.name}-memory-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.bloom_site_public_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.bloom_site_public_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.bloom_site_public_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.service_task_autoscaling_config.memory_target

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
