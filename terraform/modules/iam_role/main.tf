data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_policy" "policy" {
  name = "${var.role_name}-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Effect   = "Allow"
      Resource = var.s3_resources
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

# Attach SSM managed policy
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# KMS permissions for EBS encryption
resource "aws_iam_policy" "kms" {
  count = var.kms_key_arn != "" ? 1 : 0
  name  = "${var.role_name}-kms-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:CreateGrant",
        "kms:DescribeKey"
      ]
      Resource = var.kms_key_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "kms" {
  count      = var.kms_key_arn != "" ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.kms[0].arn
}

resource "aws_iam_instance_profile" "profile" {
  role = aws_iam_role.role.name
}