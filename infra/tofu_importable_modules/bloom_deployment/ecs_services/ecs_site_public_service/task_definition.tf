
resource "aws_ecs_task_definition" "bloom_site_public" {
  region                   = var.aws_region
  family                   = "bloom-site-public"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  execution_role_arn = var.aws_iam_role_bloom_ecs_arn
  task_role_arn      = var.aws_iam_role_bloom_container_arn

  cpu    = var.resource_limits.vcpu
  memory = var.resource_limits.memory_mib

  container_definitions = jsonencode(concat([
    {
      Name        = "bloom-site-public"
      essential   = true
      image       = var.image
      environment = [for k, v in merge(local.site_public_default_env_vars, var.env_vars) : { name = k, value = v }]
      secrets = [
        {
          name      = "MAPBOX_TOKEN",
          valueFrom = var.secretsmanager_mapbox_api_key_arn
        }
      ]
      portMappings = [
        {
          containerPort = 3000
          appProtocol   = "http"
        }
      ]
      restartPolicy = {
        enabled = false
      }
      healthCheck = {
        command = [
          "curl",
          "--fail",
          "http://127.0.0.1:3000/"
        ]
        interval    = 5 # seconds
        timeout     = 2
        retries     = 10
        startPeriod = 120 # takes about 60s to startup, padding with 2x
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-group"         = var.aws_cloudwatch_log_group_name
          "awslogs-stream-prefix" = "bloom-site-public"
        }
      }
    }
    ],
    var.otel_sidecar_container
  ))
}
