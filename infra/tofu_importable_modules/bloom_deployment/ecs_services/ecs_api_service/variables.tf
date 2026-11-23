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

variable "aws_rds_address" {
  type        = string
  description = "Address of the AWS RDS instance"
}

variable "aws_s3_private_bucket_id" {
  type        = string
  description = "AWS S3 private bucket id"
}

variable "aws_s3_public_bucket_id" {
  type        = string
  description = "AWS S3 public bucket id"
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

variable "aws_private_subnet_ids" {
  type        = set(string)
  description = "A set of subnet IDs to use with the ALB"
}

variable "aws_security_group_id" {
  type        = string
  description = "Security Group ID"
}

variable "bloom_api_image" {
  type        = string
  description = "Container image for the Bloom API."
}

variable "bloom_api_env_vars" {
  type        = map(any)
  description = "Environment variables for the Bloom API tasks. This is merged with the default env vars set in the ecs_api_task.tf file, with these variables taking precedence."
  default     = {}
}

variable "google_translate_settings" {
  type = object({
    project_id = string
    iam_user   = string
  })
  description = "Google Translate API settings. project_id is the Google Cloud project ID. iam_user is the email of the service account."
  default     = null
  validation {
    condition = var.google_translate_settings == null || (
      var.google_translate_settings.project_id != "" && var.google_translate_settings.iam_user != ""
    )
    error_message = "project_id and iam_user must not be empty strings."
  }
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

variable "otel_sidecar_env_vars" {
  type        = map(string)
  description = "OpenTelemtry Sidecar Enviroment Variables"
  default     = { OTEL_SDK_DISABLED = true } // needed when disabled or the app will keep trying to export and spam logs with errors
}

variable "resource_limits" {
  description = "ECS task resource limits for the API contianer. vcpu is in CPU units where 1024 CPU units = 1 CPU."
  type = object({
    vcpu       = number
    memory_mib = number
  })
  # Keep in sync with docker-compose.yml
  default = {
    vcpu       = 1 * 1024 # 1 CPU
    memory_mib = 2 * 1024 # 2 GiB
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

variable "bloom_api_sms_config" {
  description = "SMS configuration for the Bloom API using AWS Pinpoint SMS Voice V2. When set, provisions a phone number and configures the API to send SMS via AWS."
  type = object({
    number_type = optional(string, "LONG_CODE")
  })
  default = null
  validation {
    condition = var.bloom_api_sms_config == null || contains(
      ["LONG_CODE", "TOLL_FREE", "SHORT_CODE", "TEN_DLC"],
      var.bloom_api_sms_config.number_type
    )
    error_message = "number_type must be one of: LONG_CODE, TOLL_FREE, SHORT_CODE, TEN_DLC."
  }
}

variable "sms_phone_number" {
  type        = string
  description = "Phone number provisioned for sending SMS (E.164 format). Null if SMS is not configured."
}

variable "secretsmanager_api_jwt_signing_key_arn" {
  type        = string
  description = "TODO"
}

variable "secretsmanager_google_translate_api_key_arn" {
  type        = string
  description = "ARN for the Google Translate API key"
}
