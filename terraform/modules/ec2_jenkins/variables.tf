variable "subnet_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "security_groups" { type = list(string) }
variable "instance_profile" {}

variable "logging_target_bucket" {
  description = "The target bucket for S3 logging. Defaults to an empty string."
  type        = string
  default     = ""
}