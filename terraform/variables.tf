variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
  default     = "key"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH"
  default     = "0.0.0.0/0"
}

variable "artifact_bucket_name" {
  description = "Name for S3 bucket for Jenkins artifacts"
  type        = string
  default     = "jenkins-artifact-bucket-redluit-2026"
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t2.micro"
}