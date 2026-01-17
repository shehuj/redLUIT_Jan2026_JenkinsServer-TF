resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  name   = var.name
  description = var.description

  dynamic "ingress" {
    for_each = var.ingress
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}