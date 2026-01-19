variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "description" {
  type = string
  default = "Web SG"
}

variable "ssh_cidrs" {
  type        = list(string)
  description = "Allowed SSH CIDRs"
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type = map(string)
}