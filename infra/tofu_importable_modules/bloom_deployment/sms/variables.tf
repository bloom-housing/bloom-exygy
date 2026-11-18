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