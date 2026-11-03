variable "observability_collection_enabled" {
  type        = bool
  description = "Toggle flag to turn on/off the metrics collector for the environment"
  default     = "false"
}

variable "git_sha" {
  type        = string
  description = "This is the git_sha of the bloom core commit that is to be deployed"
  default     = ""
}