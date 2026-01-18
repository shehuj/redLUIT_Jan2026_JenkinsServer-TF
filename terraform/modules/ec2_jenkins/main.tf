data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  subnet_id              = var.subnet_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  user_data              = <<-EOF
#!/bin/bash
set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Logging setup
exec > >(tee -a /var/log/user-data.log)
exec 2>&1
echo "=== User Data Script Started at $(date) ==="

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Wait for cloud-init to complete
echo "Waiting for cloud-init to complete..."
cloud-init status --wait || true

# Update package lists
echo "Updating package lists..."
apt-get update -y

# Install essential packages for Ansible
echo "Installing Python3 and dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-apt \
    software-properties-common \
    curl \
    wget \
    ca-certificates

# Upgrade system packages (non-interactive)
echo "Upgrading system packages..."
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Clean up
echo "Cleaning up..."
apt-get autoremove -y
apt-get clean

# Create marker file
echo "User data script completed at $(date)" > /var/log/user-data-complete
echo "=== User Data Script Completed Successfully at $(date) ==="
EOF
  vpc_security_group_ids = var.security_groups
  iam_instance_profile   = var.instance_profile
  tags = {
    Name           = "JenkinsServer"
    Environment    = "production"
    Role           = "jenkins-master"
    AnsibleManaged = "true"
    OS             = "Ubuntu-22.04"
  }
}