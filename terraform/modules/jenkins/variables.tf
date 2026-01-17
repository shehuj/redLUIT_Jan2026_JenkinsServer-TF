# Required Variables

variable "instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
}

variable "artifacts_bucket_name" {
  description = "Name of the S3 bucket for Jenkins artifacts"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "Name of the IAM instance profile to attach to the EC2 instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to Jenkins resources"
  type        = map(string)
  default     = {}
}

# Optional Variables - Networking

variable "jenkins_port" {
  description = "Port for Jenkins UI"
  type        = number
  default     = 8080
}

variable "jenkins_ui_cidrs" {
  description = "CIDR blocks allowed to access Jenkins UI"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Optional Variables - Security

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for S3 bucket"
  type        = bool
  default     = false
}

variable "kms_deletion_window_days" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2"
  type        = bool
  default     = false
}

variable "enable_backup" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}

# Optional Variables - S3 Configuration

variable "enable_lifecycle_policy" {
  description = "Enable S3 lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "lifecycle_expiration_days" {
  description = "Number of days after which old versions expire"
  type        = number
  default     = 90
}

variable "enable_s3_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = false
}

variable "logging_bucket_name" {
  description = "S3 bucket name for storing access logs"
  type        = string
  default     = ""
}

# Optional Variables - EC2 Configuration

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30
}

variable "enable_elastic_ip" {
  description = "Allocate and associate an Elastic IP"
  type        = bool
  default     = false
}

# Optional Variables - Monitoring

variable "cloudwatch_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = false
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  type        = string
  default     = ""
}
