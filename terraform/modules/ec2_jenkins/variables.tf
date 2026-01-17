variable "subnet_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "security_groups" { type = list(string) }
variable "instance_profile" {}