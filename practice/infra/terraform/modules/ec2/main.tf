resource "aws_instance" "this" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Root block device configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${var.tags["Name"]}-root-volume"
    })
  }

  # Enable detailed monitoring for better observability
  monitoring = false  # Set to true if you need CloudWatch detailed monitoring (additional cost)

  # User data for initial instance setup (optional, can be used for pre-Ansible bootstrap)
  user_data = var.user_data

  # Prevent accidental termination in production
  disable_api_termination = false

  # Metadata options for enhanced security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(var.tags, {
    Name = var.tags["Name"]
  })

  lifecycle {
    ignore_changes = [
      user_data,  # Ignore user_data changes after initial creation
    ]
  }
}