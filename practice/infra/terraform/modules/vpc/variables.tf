variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default     = {}
}