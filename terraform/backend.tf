# Remote Backend Configuration Example
#
# This file demonstrates how to configure S3 backend for remote state storage
# with DynamoDB for state locking and consistency checking.
#
# SETUP INSTRUCTIONS:
# 1. Create the S3 bucket and DynamoDB table (see setup-backend.sh)
# 2. Copy this file: cp backend.tf.example backend.tf
# 3. Update the values below with your actual bucket name and region
# 4. Run: terraform init -migrate-state (to migrate existing local state)
#
# SECURITY NOTES:
# - The S3 bucket should have versioning enabled
# - The S3 bucket should have encryption enabled
# - The DynamoDB table should have point-in-time recovery enabled
# - Never commit backend.tf with actual values to public repositories

terraform {
  backend "s3" {
    # S3 bucket name for storing Terraform state
    # Must be globally unique and already exist
    bucket = "ec2-shutdown-lambda-bucket"

    # Path within the bucket where state file will be stored
    # Recommended format: <project>/<environment>/terraform.tfstate
    key = "jenkins/dev/terraform.tfstate"

    # AWS region where the S3 bucket is located
    region = "us-east-1"

    # DynamoDB table name for state locking
    # Must already exist with primary key: LockID (String)
    dynamodb_table = "dyning_table"

    # Enable encryption at rest for state file
    encrypt = true

    # Optional: Use specific AWS profile
    # profile = "terraform"

    # Optional: Add tags to the S3 state file object
    # tags = {
    #   Project     = "Jenkins"
    #   Environment = "dev"
    #   ManagedBy   = "Terraform"
    # }
  }
}
