data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.linux.id
  subnet_id              = var.subnet_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  user_data              = <<-EOF
#!/bin/bash
# Minimal setup - Ansible will handle Jenkins installation
sudo yum update -y
EOF
  vpc_security_group_ids = var.security_groups
  iam_instance_profile   = var.instance_profile
  tags = {
    Name           = "JenkinsServer"
    Environment    = "production"
    Role           = "jenkins-master"
    AnsibleManaged = "true"
  }
}