variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "s3_resources" {
  description = "List of S3 resource ARNs for bucket access"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS encryption permissions"
  type        = string
  default     = ""
}

variable "enable_ssm" {
  description = "Enable SSM Session Manager permissions"
  type        = bool
  default     = true
}