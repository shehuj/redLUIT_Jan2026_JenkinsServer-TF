# =============================================================================
# Terraform Variables - Production Deployment
# =============================================================================
# Generated: 2026-01-17
# WARNING: Do not commit this file to version control!
# =============================================================================

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

# AWS Region
aws_region = "us-east-1"

# Your Public IP (for SSH access)
public_ip = "108.243.221.242/32"

# Jenkins S3 Bucket Name (must be globally unique)
jenkins_s3_bucket_name = "jenkins-artifacts-615299732970-prod-2026"

# -----------------------------------------------------------------------------
# ENVIRONMENT CONFIGURATION
# -----------------------------------------------------------------------------

# Environment (prod enables enhanced security features automatically)
environment = "prod"

# Jenkins Instance Type (m5.xlarge = 4 vCPU, 16GB RAM)
jenkins_instance_type = "m5.xlarge"

# -----------------------------------------------------------------------------
# NETWORKING CONFIGURATION
# -----------------------------------------------------------------------------

# Jenkins Port
jenkins_port = 8080

# Additional SSH CIDR Blocks (empty = only your IP)
allowed_ssh_cidrs = []

# Jenkins UI Access - Your IP Only (SECURE)
jenkins_ui_cidrs = ["108.243.221.242/32"]

# -----------------------------------------------------------------------------
# SECURITY CONFIGURATION (Production)
# -----------------------------------------------------------------------------

# KMS Encryption for S3 (auto-enabled for prod, but explicitly set)
enable_kms_encryption = true

# Detailed CloudWatch Monitoring (auto-enabled for prod)
enable_detailed_monitoring = true

# Automated Backups (recommended for production)
enable_backup = true

# -----------------------------------------------------------------------------
# STORAGE CONFIGURATION
# -----------------------------------------------------------------------------

# S3 Lifecycle - delete old artifact versions after 90 days
s3_lifecycle_expiration_days = 90

# CloudWatch Log Retention (90 days for production)
cloudwatch_retention_days = 90

# Root Volume Size (GB) - increased for production workloads
root_volume_size = 50

# -----------------------------------------------------------------------------
# RESOURCE TAGGING
# -----------------------------------------------------------------------------

tags = {
  Project     = "Jenkins CI/CD"
  Environment = "Production"
  Owner       = "DevOps Team"
  CostCenter  = "Engineering"
  Compliance  = "SOC2"
  Backup      = "Daily"
  Terraform   = "true"
  DeployedBy  = "jenom"
  DeployDate  = "2026-01-17"
}
