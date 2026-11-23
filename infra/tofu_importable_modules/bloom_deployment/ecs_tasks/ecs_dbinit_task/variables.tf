variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use when running aws commands in local-exec provisioners."
  default     = ""
}

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

variable "aws_db_address" {
  type        = string
  description = "Address of the database"
}

variable "aws_db_instance_id" {
  type        = string
  description = "ID of the AWS RDS instance"
}

variable "aws_db_master_username" {
  type        = string
  description = "db master username"
}

variable "aws_db_master_user_secret" {
  type = list(object({
    kms_key_id    = string
    secret_arn    = string
    secret_status = string
  }))
  description = "AWS Managed db master user secret"
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

variable "aws_private_subnet_ids" {
  type        = set(string)
  description = "A set of subnet IDs to use with the ALB"
}

variable "aws_security_group_id" {
  type        = string
  description = "Security Group ID"
}

variable "bloom_dbinit_run_number" {
  type        = number
  description = "The run number is used to trigger additional runs of the dbinit process. The dbinit process will not be re-triggered unless the run number is changed."
  default     = 1
}

variable "bloom_dbinit_image" {
  type        = string
  description = "Container image for the Bloom dbinit process."
}
