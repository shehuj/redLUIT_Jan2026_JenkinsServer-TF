# Security Group for Jenkins
resource "aws_security_group" "this" {
  name_prefix = "jenkins-sg-"
  description = "Security group for Jenkins server with SSH and UI access"
  vpc_id      = data.aws_vpc.default.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.tags["Environment"]}-jenkins-sg"
    }
  )
}

# SSH access rules
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  description       = "SSH access from allowed CIDR blocks"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_cidr_blocks
  security_group_id = aws_security_group.this.id
}

# Jenkins UI access rules
resource "aws_security_group_rule" "jenkins_ui" {
  type              = "ingress"
  description       = "Jenkins UI access"
  from_port         = var.jenkins_port
  to_port           = var.jenkins_port
  protocol          = "tcp"
  cidr_blocks       = var.jenkins_ui_cidrs
  security_group_id = aws_security_group.this.id
}

# Outbound traffic rules
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

# KMS key for S3 bucket encryption (if enabled)
resource "aws_kms_key" "s3" {
  count = var.enable_kms_encryption ? 1 : 0

  description             = "KMS key for Jenkins S3 bucket encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.tags["Environment"]}-jenkins-s3-kms"
    }
  )
}

resource "aws_kms_alias" "s3" {
  count = var.enable_kms_encryption ? 1 : 0

  name          = "alias/${var.tags["Environment"]}-jenkins-s3"
  target_key_id = aws_kms_key.s3[0].key_id
}

# S3 Bucket for Jenkins artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_bucket_name

  tags = merge(
    var.tags,
    {
      Name       = var.artifacts_bucket_name
      Purpose    = "Jenkins build artifacts storage"
      Encryption = var.enable_kms_encryption ? "KMS" : "AES256"
    }
  )
}

# S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 Bucket Public Access Block (security best practice)
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms_encryption ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms_encryption ? aws_kms_key.s3[0].arn : null
    }
    bucket_key_enabled = var.enable_kms_encryption
  }
}

# S3 Lifecycle Policy (manage object versions and costs)
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  count = var.enable_lifecycle_policy ? 1 : 0

  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-to-ia"
    status = var.environment == "prod" ? "Enabled" : "Disabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# S3 Bucket Policy (enforce encryption)
resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.artifacts.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = var.enable_kms_encryption ? "aws:kms" : "AES256"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# S3 Bucket Logging (audit trail)
resource "aws_s3_bucket_logging" "artifacts" {
  count = var.enable_s3_logging ? 1 : 0

  bucket = aws_s3_bucket.artifacts.id

  target_bucket = var.logging_bucket_name
  target_prefix = "jenkins-artifacts-logs/"
}

# Jenkins EC2 Instance
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.this.id]
  subnet_id              = data.aws_subnets.default.ids[0]
  iam_instance_profile   = var.iam_instance_profile_name

  # IMDSv2 requirement (security best practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Require IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # EBS root volume encryption
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size
    iops        = 3000
    throughput  = 125

    tags = merge(
      var.tags,
      {
        Name = "${var.tags["Environment"]}-jenkins-root-volume"
      }
    )
  }

  # Enable detailed monitoring for production
  monitoring = var.enable_detailed_monitoring

  # User data script
  user_data = file("${path.module}/user-data.sh")

  # Enable termination protection for production
  disable_api_termination = var.environment == "prod" ? true : false

  # Instance lifecycle
  lifecycle {
    ignore_changes = [
      ami,      # Allow manual AMI updates
      user_data # Prevent replacement on user_data changes
    ]
  }

  tags = merge(
    var.tags,
    {
      Name       = "${var.tags["Environment"]}-jenkins-server"
      Backup     = var.enable_backup ? "true" : "false"
      Monitoring = var.enable_detailed_monitoring ? "detailed" : "basic"
    }
  )
}

# CloudWatch Log Group for Jenkins
resource "aws_cloudwatch_log_group" "jenkins" {
  name              = "/aws/ec2/jenkins/${var.environment}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.enable_kms_encryption ? aws_kms_key.s3[0].arn : null

  tags = merge(
    var.tags,
    {
      Name = "${var.tags["Environment"]}-jenkins-logs"
    }
  )
}

# Elastic IP for stable public IP (optional)
resource "aws_eip" "jenkins" {
  count = var.enable_elastic_ip ? 1 : 0

  instance = aws_instance.this.id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.tags["Environment"]}-jenkins-eip"
    }
  )
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.tags["Environment"]}-jenkins-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors Jenkins server CPU utilization"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = aws_instance.this.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.tags["Environment"]}-jenkins-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors Jenkins server status checks"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = aws_instance.this.id
  }

  tags = var.tags
}
