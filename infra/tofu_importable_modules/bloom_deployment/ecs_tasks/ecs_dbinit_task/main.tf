resource "aws_ecs_task_definition" "bloom_dbinit" {
  region                   = var.aws_region
  family                   = "bloom-dbinit"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  execution_role_arn = var.aws_iam_role_bloom_ecs_arn
  task_role_arn      = var.aws_iam_role_bloom_container_arn

  # Keep in sync with docker-compose.yml
  # TODO fix this
  cpu    = 256 # 0.25 vCPU
  memory = 512 # MiB

  container_definitions = jsonencode([
    {
      name  = "bloom-dbinit"
      image = var.bloom_dbinit_image

      secrets = [
        {
          name      = "PGPASSWORD"
          valueFrom = "${var.aws_db_master_user_secret[0].secret_arn}:password::"
        }
      ]
      entryPoint = ["psql"]
      command = [
        "--host=${var.aws_db_address}",
        "--port=5432",
        "--dbname=postgres",
        "--username=${var.aws_db_master_username}",
        "--echo-queries",
        "--echo-hidden",
        "--file=rds.init.sql",
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-group"         = var.aws_cloudwatch_log_group_name
          "awslogs-stream-prefix" = "bloom-dbinit"
        }
      }
    }
  ])
}

# TODO: remove local exec provisioner once
# https://github.com/hashicorp/terraform-provider-aws/issues/29871 is implemented.
resource "null_resource" "bloom_dbinit_run" {
  triggers = {
    run_number     = var.bloom_dbinit_run_number
    db_instance_id = var.aws_db_instance_id
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "Starting Bloom dbinit task..."

      task_arn="$(
        aws ecs run-task \
          ${var.aws_profile != "" ? "--profile ${var.aws_profile}" : ""} \
          --region ${var.aws_region} \
          --cluster ${var.aws_ecs_cluster_arn} \
          --launch-type FARGATE \
          --task-definition ${aws_ecs_task_definition.bloom_dbinit.arn} \
          --network-configuration "awsvpcConfiguration={subnets=[${join(",", [for s in var.aws_private_subnet_ids : s.id])}],securityGroups=[${var.aws_security_group_id}],assignPublicIp=DISABLED}" \
          --query 'tasks[0].taskArn' \
          --output text
      )"

      if [ -z "$task_arn" ] || [ "$task_arn" = "None" ]; then
        echo "ERROR: failed to start Bloom dbinit task" >&2
        exit 1
      fi

      echo "Task ARN: $task_arn"
      echo "Waiting for task to stop..."
      aws ecs wait tasks-stopped \
        ${var.aws_profile != "" ? "--profile ${var.aws_profile}" : ""} \
        --region ${var.aws_region} \
        --cluster ${var.aws_ecs_cluster_arn} \
        --tasks "$task_arn"

      exit_code="$(
        aws ecs describe-tasks \
          ${var.aws_profile != "" ? "--profile ${var.aws_profile}" : ""} \
          --region ${var.aws_region} \
          --cluster ${var.aws_ecs_cluster_arn} \
          --tasks "$task_arn" \
          --query 'tasks[0].containers[0].exitCode' \
          --output text
      )"

      if [ "$exit_code" != "0" ]; then
        reason="$(
          aws ecs describe-tasks \
            ${var.aws_profile != "" ? "--profile ${var.aws_profile}" : ""} \
            --region ${var.aws_region} \
            --cluster ${var.aws_ecs_cluster_arn} \
            --tasks "$task_arn" \
            --query 'tasks[0].stoppedReason' \
            --output text
        )"
        echo "ERROR: Bloom dbinit task failed (exitCode=$exit_code). stoppedReason=$reason" >&2
        exit 1
      fi

      echo "Bloom dbinit task succeeded."
    EOT
  }
}
