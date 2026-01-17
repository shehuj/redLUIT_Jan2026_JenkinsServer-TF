# Data source for current AWS account and caller identity
data "aws_caller_identity" "current" {}

# KMS key for EBS encryption
resource "aws_kms_key" "jenkins" {
  description             = var.description
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = var.key_alias
  }
}

# KMS alias
resource "aws_kms_alias" "jenkins" {
  name          = var.key_alias
  target_key_id = aws_kms_key.jenkins.key_id
}
