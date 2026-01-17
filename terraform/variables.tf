variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "public_ip" {
  description = "Your public IP for SSH access (CIDR)"
  type        = string

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
}