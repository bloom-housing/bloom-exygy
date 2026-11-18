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

variable "bloom_dbseed_image" {
  type        = string
  description = "Container image for the Bloom dbseed process. Leave empty to disable running the dbseed process."
  default     = ""
}

variable "vpc_cidr_range" {
  type        = string
  description = "The CIDR range to use for the Bloom VPC. Must be a /22 block in the RFC 1918 private IP space."
  default     = "10.0.0.0/22"
  validation {
    condition = (
      cidrcontains("10.0.0.0/8", var.vpc_cidr_range) ||
      cidrcontains("172.16.0.0/12", var.vpc_cidr_range) ||
      cidrcontains("192.168.0.0/16", var.vpc_cidr_range)
    )
    error_message = "Must be in the RFC 1918 private IP space."
  }
  validation {
    condition     = cidrnetmask(var.vpc_cidr_range) == cidrnetmask("10.0.0.0/22")
    error_message = "Must be a /22."
  }
}

# TODO this doesn't seem to be needed anymore. Not sure.
variable "vpc_peering_settings" {
  type = object({
    aws_account_number        = number
    vpc_id                    = string
    allowed_security_group_id = string
    allowed_cidr_range        = string
  })
  description = "Details of an existing VPC. If not null, a VPC peering request from the Bloom VPC will be created. Processes in the allowed_cidr_range and allowed_security_group_id in the existing VPC will be allowed to send traffic to the Bloom database."
  default     = null

  validation {
    condition = var.vpc_peering_settings == null || (
      var.vpc_peering_settings.aws_account_number != 0 &&
      var.vpc_peering_settings.vpc_id != "" &&
      var.vpc_peering_settings.allowed_security_group_id != "" &&
      var.vpc_peering_settings.allowed_cidr_range != ""
    )
    error_message = "All fields of vpc_peering_settings must be set to non-empty values."
  }

  validation {
    condition = var.vpc_peering_settings == null || (
      cidrcontains("10.0.0.0/8", var.vpc_peering_settings.allowed_cidr_range) ||
      cidrcontains("172.16.0.0/12", var.vpc_peering_settings.allowed_cidr_range) ||
      cidrcontains("192.168.0.0/16", var.vpc_peering_settings.allowed_cidr_range)
    )
    error_message = "CIDR range in peered VPC must be in the RFC 1918 private IP space."
  }
}