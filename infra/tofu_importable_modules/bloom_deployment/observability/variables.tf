variable "aws_profile" {
  type        = string
  description = "Optional AWS CLI profile to use when running aws commands in local-exec provisioners. IMPORTANT: if not specified, you must authenticate the AWS CLI some other way like with environment variables."
  default     = ""
}

variable "aws_account_number" {
  type        = string
  description = "AWS account number that is being configured."
}

variable "aws_cloudwatch_log_group_name" {
  type        = string
  description = "CloudWatch log group the service writes to."
}

variable "aws_region" {
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

variable "bloom_otel_collector_image" {
  type        = string
  description = "Container image for the AWS Distro for OpenTelemetry collector sidecar."
}

variable "grafana_editor_group_ids" {
  type        = list(string)
  description = "IAM Identity Center group IDs that should have the editor role on the managed Grafana instance."
  default     = []
}

variable "observability_collection_enabled" {
  type    = bool
  default = false
}
