variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "ssh_allowed_cidrs" {
  type = list(string)
}

variable "ec2_ami" {
  type = string
}

variable "ec2_instance_type" {
  type = string
}

variable "common_tags" {
  type = map(string)
}