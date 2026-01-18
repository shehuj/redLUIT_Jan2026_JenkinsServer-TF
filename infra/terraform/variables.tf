variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed to SSH into instances"
}

variable "ec2_ami" {
  type        = string
  description = "AMI ID for EC2 instances"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "ssh_key_name" {
  type        = string
  description = "Name of the SSH key pair for EC2 access (must exist in AWS)"
  default     = null
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
}