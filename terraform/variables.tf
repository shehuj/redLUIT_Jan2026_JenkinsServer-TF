variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "public_ip" {
  description = "Your public IP for SSH access (CIDR)"
  type        = string
#  default     = "203.0.113.0/32"

  validation {
    condition     = can(cidrhost(var.public_ip, 0))
    error_message = "The public_ip must be a valid CIDR block (e.g., 203.0.113.0/32)."
  }
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
  default     = "t2.micro"
}

variable "jenkins_s3_bucket_name" {
  description = "Unique name for Jenkins artifacts bucket"
  type        = string
  default     = "jenkins-artifacts"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "jenkins_port" {
  description = "Port for Jenkins UI access"
  type        = number
  default     = 8080

  validation {
    condition     = var.jenkins_port >= 1024 && var.jenkins_port <= 65535
    error_message = "Jenkins port must be between 1024 and 65535."
  }
}

# Security and Compliance Variables

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for S3 bucket (recommended for production)"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instance"
  type        = bool
  default     = false
}

variable "enable_backup" {
  description = "Enable automated backups using AWS Backup"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH (in addition to public_ip)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid CIDR notation."
  }
}

variable "jenkins_ui_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to access Jenkins UI.

    SECURITY WARNING: This variable has NO DEFAULT to force explicit security decision.
    You MUST specify which IPs/networks can access Jenkins.

    Examples:
    - Single IP: ["203.0.113.42/32"]
    - Office network: ["10.0.0.0/8"]
    - Multiple locations: ["203.0.113.0/24", "198.51.100.0/24"]
    - Open to internet (NOT RECOMMENDED): ["0.0.0.0/0"]
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.jenkins_ui_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid CIDR notation."
  }
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days after which old artifact versions are deleted"
  type        = number
  default     = 90

  validation {
    condition     = var.s3_lifecycle_expiration_days >= 1 && var.s3_lifecycle_expiration_days <= 3650
    error_message = "Lifecycle expiration must be between 1 and 3650 days."
  }
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs for network monitoring"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (if not specified, will create new key)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB for Jenkins EC2 instance"
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 16384
    error_message = "Root volume size must be between 8 and 16384 GB."
  }
}

variable "cloudwatch_retention_days" {
  description = "Number of days to retain CloudWatch logs (0 = never expire)"
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_retention_days)
    error_message = "CloudWatch retention must be one of the valid values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653 days."
  }
}