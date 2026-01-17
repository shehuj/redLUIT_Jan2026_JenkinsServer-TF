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

variable "jenkins_port" {
  description = "Port for Jenkins UI"
  type        = number
  default     = 8080
}

variable "tags" {
  description = "Tags to apply to Jenkins resources"
  type        = map(string)
  default     = {}
}
