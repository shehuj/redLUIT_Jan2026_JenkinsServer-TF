# Local values for centralized configuration and DRY principle
locals {
  # Common naming prefix
  name_prefix = "jenkins-${var.environment}"

  # Common tags applied to all resources
  # Note: CreatedDate tag removed to prevent perpetual drift
  # Use git history or AWS resource creation timestamp instead
  common_tags = merge(
    var.tags,
    {
      Project     = "Jenkins CI/CD"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "redLUIT_Jan2026_JenkinsServer-TF"
    }
  )

  # Security tags for compliance
  security_tags = {
    DataClassification = "Internal"
    ComplianceScope    = "SOC2"
    BackupRequired     = "true"
    EncryptionRequired = "true"
  }

  # All tags combined
  all_tags = merge(local.common_tags, local.security_tags)

  # IAM resource names
  iam_role_name             = "${local.name_prefix}-ec2-role"
  iam_policy_name           = "${local.name_prefix}-s3-policy"
  iam_instance_profile_name = "${local.name_prefix}-instance-profile"

  # S3 bucket configuration
  s3_bucket_name = var.jenkins_s3_bucket_name

  # Enable additional security features for production
  enable_kms_encryption      = var.environment == "prod" ? true : var.enable_kms_encryption
  enable_s3_lifecycle        = true
  enable_detailed_monitoring = var.environment == "prod" ? true : var.enable_detailed_monitoring
  enable_imdsv2_required     = true

  # Backup retention and logging
  backup_retention_days = var.environment == "prod" ? 90 : 30

  # EC2 configuration with environment-based defaults
  root_volume_size = var.root_volume_size

  # CloudWatch configuration with environment-based defaults
  cloudwatch_retention_days = var.cloudwatch_retention_days != 30 ? var.cloudwatch_retention_days : (
    var.environment == "prod" ? 90 : 30
  )
}
