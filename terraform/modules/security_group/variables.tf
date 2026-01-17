variable "vpc_id" {}
variable "name" {}
variable "description" {}
variable "ingress" {
  type = list(object({
    from     = number
    to       = number
    protocol = string
    cidr     = list(string)
  }))
}