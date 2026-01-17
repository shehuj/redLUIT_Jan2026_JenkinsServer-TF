# IAM Instance Profile Module
# Creates IAM role, policy, and instance profile for Jenkins EC2 instance
module "jenkins_iam" {
  source = "./modules/iam-instance-profile"

  role_name             = local.iam_role_name
  instance_profile_name = local.iam_instance_profile_name
  policy_name           = local.iam_policy_name
  s3_bucket_arn         = module.jenkins.s3_bucket_arn

  tags = local.all_tags
}

# Jenkins Server Module
# Creates EC2 instance, security group, and S3 bucket for Jenkins
module "jenkins" {
  source = "./modules/jenkins"

  # Required variables
  instance_type             = var.jenkins_instance_type
  ssh_cidr_blocks           = concat([var.public_ip], var.allowed_ssh_cidrs)
  artifacts_bucket_name     = local.s3_bucket_name
  iam_instance_profile_name = module.jenkins_iam.instance_profile_name
  environment               = var.environment

  # Networking
  jenkins_port     = var.jenkins_port
  jenkins_ui_cidrs = var.jenkins_ui_cidrs

  # Security
  enable_kms_encryption      = local.enable_kms_encryption
  enable_detailed_monitoring = local.enable_detailed_monitoring
  enable_backup              = var.enable_backup

  # S3 Configuration
  enable_lifecycle_policy   = local.enable_s3_lifecycle
  lifecycle_expiration_days = var.s3_lifecycle_expiration_days
  enable_s3_logging         = false # Would require separate logging bucket
  logging_bucket_name       = ""

  # EC2 Configuration
  root_volume_size  = local.root_volume_size
  enable_elastic_ip = var.environment == "prod" ? true : false

  # Monitoring
  cloudwatch_retention_days = local.cloudwatch_retention_days
  enable_cloudwatch_alarms  = var.environment == "prod" ? true : false
  alarm_sns_topic_arn       = "" # Configure if SNS topic exists

  tags = local.all_tags
}