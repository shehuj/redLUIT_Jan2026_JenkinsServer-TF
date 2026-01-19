variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m5.xlarge"
}

variable "key_pair" {
  description = "EC2 SSH Key Pair"
  type        = string
  default     = "key"
}

variable "ssh_allowed_cidrs" {
  description = "List of CIDR blocks allowed to SSH into Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Open to all IPs. Restrict in production.
}

variable "artifacts_bucket_name" {
  description = "Name of the S3 bucket for Jenkins artifacts (must be globally unique)"
  type        = string
  default     = "jenkinsproject-artifacts-bucket"
}