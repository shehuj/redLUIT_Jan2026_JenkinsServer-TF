variable "name" {
  description = "Name prefix for NAT instance resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where NAT instance will be created"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for NAT instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for NAT instance"
  type        = string
  default     = "t3.nano"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets that will use this NAT instance"
  type        = list(string)
}
