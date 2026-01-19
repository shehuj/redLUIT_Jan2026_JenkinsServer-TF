terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# S3 bucket for Jenkins artifacts
resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = var.artifacts_bucket_name

  tags = {
    Name      = "jenkins-artifacts"
    ManagedBy = "Terraform"
    Project   = "JenkinsProject"
  }
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for artifact history
resource "aws_s3_bucket_versioning" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy to manage old artifacts
resource "aws_s3_bucket_lifecycle_configuration" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  rule {
    id     = "delete-old-artifacts"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    expiration {
      days = 180
    }
  }
}

# IAM role for Jenkins EC2 instance
resource "aws_iam_role" "jenkins" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "jenkins-ec2-role"
    ManagedBy = "Terraform"
    Project   = "JenkinsProject"
  }
}

# IAM policy for S3 access
resource "aws_iam_role_policy" "jenkins_s3_access" {
  name = "jenkins-s3-access"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.jenkins_artifacts.arn,
          "${aws_s3_bucket.jenkins_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# IAM instance profile for EC2
resource "aws_iam_instance_profile" "jenkins" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins.name

  tags = {
    Name      = "jenkins-instance-profile"
    ManagedBy = "Terraform"
    Project   = "JenkinsProject"
  }
}

# Create security group for Jenkins
resource "aws_security_group" "jenkins" {
  name        = "jenkinsProject-sg"
  description = "Security group for Jenkins server - jenkinsProject"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
    description = "Allow SSH from specified CIDR blocks"
  }

  # Jenkins web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Jenkins web interface"
  }

  # HTTPS (for future use)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name      = "jenkinsProject-sg"
    ManagedBy = "Terraform"
    Project   = "JenkinsProject"
  }
}

# EC2 instance for Jenkins
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  key_name               = var.key_pair
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name      = "jenkins-server"
    ManagedBy = "Terraform"
    Project   = "JenkinsProject"
  }

  depends_on = [
    aws_iam_instance_profile.jenkins,
    aws_iam_role_policy.jenkins_s3_access
  ]
}
