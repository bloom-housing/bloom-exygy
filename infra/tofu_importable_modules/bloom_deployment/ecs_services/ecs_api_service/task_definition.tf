resource "aws_ecs_task_definition" "bloom_api" {
  region                   = var.aws_region
  family                   = "bloom-api"
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
      Name        = "bloom-api"
      essential   = true
      image       = var.bloom_api_image
      environment = [for k, v in merge(local.api_default_env_vars, var.otel_sidecar_env_vars, var.bloom_api_env_vars) : { name = k, value = v }]
      entryPoint  = ["bash"]
      # TODO: Once https://github.com/prisma/prisma/issues/7869 is implemented, get rid of the bash
      # hack for the prisma migrate command.
      command = [
        "-c",
        "export DATABASE_URL=\"postgres://$${DB_USER}:$(node -e \"const S=require('@aws-sdk/rds-signer');(new S.Signer({hostname:'$${DB_HOST}',port:'$${DB_PORT}',username:'$${DB_USER}'})).getAuthToken().then(t=>console.log(encodeURIComponent(t)));\")@$${DB_HOST}:$${DB_PORT}/$${DB_DATABASE}\" && yarn db:migration:run && yarn start:prod",
      ]
      secrets = [
        {
          name      = "APP_SECRET",
          valueFrom = var.secretsmanager_api_jwt_signing_key_arn
        },
        {
          name      = "GOOGLE_API_KEY",
          valueFrom = var.secretsmanager_google_translate_api_key_arn
        }
      ]
      portMappings = [
        {
          name          = "http"
          appProtocol   = "http"
          containerPort = 3100
        }
      ]
      restartPolicy = {
        enabled = false
      }
      healthCheck = {
        command = [
          "curl",
          "--fail",
          "http://127.0.0.1:3100/"
        ]
        interval    = 5 # seconds
        timeout     = 2 # seconds
        retries     = 10
        startPeriod = 10 # seconds
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-group"         = var.aws_cloudwatch_log_group_name
          "awslogs-stream-prefix" = "bloom-api"
        }
      }
    }
    ],
    var.otel_sidecar_container
  ))
}
