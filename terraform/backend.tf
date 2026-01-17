# ========================================================================
# REMOTE BACKEND CONFIGURATION TEMPLATE
# ========================================================================
#
# ⚠️  WARNING: This file contains TEMPLATE values only!
# ⚠️  DO NOT use as-is - it will FAIL or use wrong resources!
#
# This file demonstrates how to configure S3 backend for remote state storage
# with DynamoDB for state locking and consistency checking.
#
# ========================================================================
# SETUP INSTRUCTIONS
# ========================================================================
#
# 1. Create S3 bucket and DynamoDB table:
#    Run: ./setup-backend.sh
#    (See BACKEND.md for detailed documentation)
#
# 2. Update the values below with YOUR actual resource names:
#    - Replace YOUR-TERRAFORM-STATE-BUCKET with your S3 bucket name
#    - Replace YOUR-LOCK-TABLE with your DynamoDB table name
#    - Update region if different from us-east-1
#    - Update key path for your environment
#
# 3. Uncomment the backend configuration block below
#
# 4. Migrate existing state (if you have local state):
#    Run: terraform init -migrate-state
#    Or for fresh start: terraform init
#
# ========================================================================
# SECURITY REQUIREMENTS
# ========================================================================
#
# Before enabling this backend, ensure:
# ✓ S3 bucket has versioning enabled (prevents state corruption)
# ✓ S3 bucket has encryption enabled (protects sensitive data)
# ✓ S3 bucket has public access blocked (prevents leaks)
# ✓ DynamoDB table has point-in-time recovery enabled (disaster recovery)
# ✓ IAM permissions are configured (see BACKEND.md)
# ✓ This file is in .gitignore (never commit actual values to public repos)
#
# The setup-backend.sh script configures all of these automatically.
#
# ========================================================================

# ⚠️  UNCOMMENT AND UPDATE THE BLOCK BELOW AFTER RUNNING setup-backend.sh
#
# terraform {
#   backend "s3" {
#     # S3 bucket name for storing Terraform state
#     # Must be globally unique and already exist
#     # REPLACE WITH YOUR ACTUAL BUCKET NAME
#     bucket = "YOUR-TERRAFORM-STATE-BUCKET"
#
#     # Path within the bucket where state file will be stored
#     # Recommended format: <project>/<environment>/terraform.tfstate
#     # UPDATE FOR YOUR ENVIRONMENT (dev, staging, prod)
#     key = "jenkins/dev/terraform.tfstate"
#
#     # AWS region where the S3 bucket is located
#     # UPDATE IF USING A DIFFERENT REGION
#     region = "us-east-1"
#
#     # DynamoDB table name for state locking
#     # Must already exist with primary key: LockID (String)
#     # REPLACE WITH YOUR ACTUAL TABLE NAME
#     dynamodb_table = "YOUR-LOCK-TABLE"
#
#     # Enable encryption at rest for state file
#     encrypt = true
#
#     # Optional: Use specific AWS profile
#     # profile = "terraform"
#   }
# }
