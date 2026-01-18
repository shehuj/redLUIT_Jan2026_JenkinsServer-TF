variable "ami" {
  type        = string
  description = "AMI ID for the EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the instance will be launched"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to attach to the instance"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name for instance access"
  default     = null
}

variable "user_data" {
  type        = string
  description = "User data script to run on instance launch"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the instance and volumes"
}