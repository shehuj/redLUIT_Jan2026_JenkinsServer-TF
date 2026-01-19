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

variable "jenkins_sg_id" {
  description = "Security Group ID for Jenkins"
  type        = string
  default = "sg-0bfcde60ef49a5dcd"
}

variable "key_pair" {
  description = "EC2 SSH Key Pair"
  type        = string
  default     = "key"
}