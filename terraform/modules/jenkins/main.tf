# Security Group for Jenkins
resource "aws_security_group" "this" {
  name        = "jenkins-sg"
  description = "Allow SSH from my IP and HTTP Jenkins"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  # Jenkins UI access
  ingress {
    description = "Jenkins UI"
    from_port   = var.jenkins_port
    to_port     = var.jenkins_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# S3 Bucket for Jenkins artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_bucket_name

  tags = var.tags
}

# S3 Bucket ACL (separate resource per AWS provider v4+ requirements)
resource "aws_s3_bucket_acl" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  acl    = "private"
}

# Jenkins EC2 Instance
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.this.id]
  subnet_id              = data.aws_subnets.default.ids[0]
  iam_instance_profile   = var.iam_instance_profile_name

  user_data = file("${path.module}/user-data.sh")

  tags = merge(
    var.tags,
    {
      Name = "Terraform-Jenkins"
    }
  )
}
