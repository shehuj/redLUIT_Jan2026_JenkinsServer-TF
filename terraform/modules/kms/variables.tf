variable "key_alias" {
  description = "Alias for the KMS key (must start with 'alias/')"
  type        = string
  default     = "alias/jenkins-ebs"
}

variable "description" {
  description = "Description for the KMS key"
  type        = string
  default     = "KMS key for Jenkins EBS encryption"
}
