variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "jenkins_sg_id" {
  description = "Security Group ID for Jenkins"
  type        = string
}

variable "key_pair" {
  description = "EC2 SSH Key Pair"
  type        = string
}