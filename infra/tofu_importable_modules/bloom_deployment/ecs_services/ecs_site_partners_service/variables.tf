variable "aws_region" { # TODO move validations into top level module
  type        = string
  description = "Region to deploy AWS resources to"
  validation {
    condition = (
      var.aws_region == "us-east-1" ||
      var.aws_region == "us-east-2" ||
      var.aws_region == "us-west-1" ||
      var.aws_region == "us-west-2"
    )
    error_message = "Must be 'us-east-1', 'us-east-2', 'us-west-1', or 'us-west-2'."
  }
}

variable "aws_ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}

variable "aws_ecs_cluster_arn" {
  type        = string
  description = "ECS Cluster Arn"
}

variable "aws_iam_role_bloom_ecs_arn" {
  type        = string
  description = "IAM Role for the Bloom ECS Cluster" # TODO is this right?
}

variable "aws_iam_role_bloom_container_arn" {
  type        = string
  description = "IAM Role for the Bloom API Container."
}

variable "aws_cloudwatch_log_group_name" {
  type        = string
  description = "CloudWatch log group the service writes to."
}

variable "aws_lb_target_group_site_partners_arn" {
  type        = string
  description = "ARN of the ALB target group for the partners site."
}

variable "aws_private_subnet_ids" {
  type        = set(string)
  description = "A set of subnet IDs to use with the ALB"
}

variable "aws_security_group_id" {
  type        = string
  description = "Security Group ID"
}

variable "env_vars" {
  type        = map(any)
  description = "Environment variables for the Bloom API tasks. This is merged with the default env vars set in the ecs_api_task.tf file, with these variables taking precedence."
  default     = {}
}

variable "image" {
  type        = string
  description = "Image for the ECS task to run"
}

variable "aws_service_discovery_http_namespace_arn" {
  type        = string
  description = "value"
}

variable "otel_sidecar_container" {
  type        = list(map(any))
  description = "OpenTelemetry Sidecar Container definition"
  default     = []
}

variable "resource_limits" {
  description = "ECS task resource limits for the API contianer. vcpu is in CPU units where 1024 CPU units = 1 CPU."
  type = object({
    vcpu       = number
    memory_mib = number
  })
  # Keep in sync with docker-compose.yml
  default = {
    vcpu       = 2 * 1024 # 1 CPU
    memory_mib = 4 * 1024 # 2 GiB
  }
}

variable "service_task_autoscaling_config" {
  type = object({
    cpu_target    = number
    memory_target = number

    min_tasks = number
    max_tasks = number
  })

  default = {
    cpu_target    = 50
    memory_target = 50

    min_tasks = 1
    max_tasks = 2
  }

  validation {
    condition = (var.service_task_autoscaling_config.min_tasks > 0 &&
    var.service_task_autoscaling_config.min_tasks <= var.service_task_autoscaling_config.max_tasks)

    error_message = "min_tasks must be greater than 0 but less than or equal to max_tasks"
  }
}

variable "secretsmanager_mapbox_api_key_arn" {
  type        = string
  description = "ARN for the Mapbox API key"
}
