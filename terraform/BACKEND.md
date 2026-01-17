# Terraform Remote Backend Configuration

This document explains how to set up and use remote state storage for this Terraform project using AWS S3 and DynamoDB.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Setup](#manual-setup)
- [Backend Configuration](#backend-configuration)
- [State Migration](#state-migration)
- [IAM Permissions](#iam-permissions)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

## Overview

Remote state storage provides several benefits over local state:

- **Team Collaboration**: Multiple team members can work on the same infrastructure
- **State Locking**: Prevents concurrent modifications that could corrupt state
- **Encryption**: State data is encrypted at rest and in transit
- **Versioning**: Previous state versions are retained for recovery
- **Backup**: Automatic backups through S3 versioning

This project uses:
- **S3** for storing Terraform state files
- **DynamoDB** for state locking and consistency checking

## Prerequisites

Before setting up the backend, ensure you have:

1. **AWS CLI** installed and configured
   ```bash
   aws --version  # Should show version 2.x or higher
   aws sts get-caller-identity  # Verify credentials work
   ```

2. **jq** installed (for JSON parsing)
   ```bash
   # macOS
   brew install jq

   # Ubuntu/Debian
   sudo apt-get install jq

   # Amazon Linux
   sudo yum install jq
   ```

3. **IAM Permissions** (see [IAM Permissions](#iam-permissions) section)

4. **Terraform** v1.0 or higher
   ```bash
   terraform version
   ```

## Quick Start

The fastest way to set up the backend is using the provided script:

```bash
# Navigate to the terraform directory
cd terraform

# Run the setup script (interactive)
./setup-backend.sh

# Or specify custom names
./setup-backend.sh --bucket my-terraform-state --table my-lock-table --region us-west-2

# Or use a specific AWS profile
./setup-backend.sh --profile production
```

The script will:
1. Create an S3 bucket with versioning and encryption
2. Block all public access to the bucket
3. Create a DynamoDB table for state locking
4. Enable point-in-time recovery on the table
5. Print the configuration to add to `backend.tf`

After the script completes, follow the [Backend Configuration](#backend-configuration) section.

## Manual Setup

If you prefer to create resources manually:

### Step 1: Create S3 Bucket

```bash
# Set variables
BUCKET_NAME="terraform-state-YOUR-ACCOUNT-ID-us-east-1"
AWS_REGION="us-east-1"

# Create bucket (us-east-1)
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION

# For other regions, add LocationConstraint
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Step 2: Create DynamoDB Table

```bash
# Set variables
TABLE_NAME="terraform-state-lock"
AWS_REGION="us-east-1"

# Create table
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --region $AWS_REGION \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Enable point-in-time recovery
aws dynamodb update-continuous-backups \
  --table-name $TABLE_NAME \
  --region $AWS_REGION \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

## Backend Configuration

After creating the S3 bucket and DynamoDB table:

### Step 1: Update backend.tf

Open `terraform/backend.tf` and uncomment the backend block, then update with your values:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-123456789012-us-east-1"  # Your bucket name
    key            = "jenkins/dev/terraform.tfstate"            # State file path
    region         = "us-east-1"                                # Your region
    dynamodb_table = "terraform-state-lock"                     # Your table name
    encrypt        = true
  }
}
```

**Key Path Convention:**
- Format: `<project>/<environment>/terraform.tfstate`
- Examples:
  - Development: `jenkins/dev/terraform.tfstate`
  - Staging: `jenkins/staging/terraform.tfstate`
  - Production: `jenkins/prod/terraform.tfstate`

### Step 2: Initialize Backend

```bash
cd terraform

# If you have existing local state (terraform.tfstate file)
terraform init -migrate-state

# If starting fresh
terraform init
```

When prompted about migrating state, type `yes` to confirm.

### Step 3: Verify Remote State

```bash
# Check state file was uploaded to S3
aws s3 ls s3://YOUR-BUCKET-NAME/jenkins/dev/

# You should see: terraform.tfstate
```

## State Migration

### Migrating from Local to Remote State

If you already have infrastructure deployed with local state:

```bash
# 1. Backup your local state
cp terraform.tfstate terraform.tfstate.backup

# 2. Update backend.tf with your S3/DynamoDB values

# 3. Run init with migration
terraform init -migrate-state

# 4. Verify state was migrated
terraform state list

# 5. Verify remote state exists
aws s3 ls s3://YOUR-BUCKET-NAME/jenkins/dev/terraform.tfstate

# 6. Remove local state files (after verifying remote state works)
rm terraform.tfstate terraform.tfstate.backup
```

### Migrating Between Backends

To change backend configuration (e.g., different bucket or key):

```bash
# 1. Update backend.tf with new values

# 2. Re-initialize with migration
terraform init -migrate-state -reconfigure

# 3. Verify new backend
terraform state list
```

### Recovering from State Lock

If state becomes locked (e.g., interrupted operation):

```bash
# Check DynamoDB for lock
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use the Lock ID from error message)
terraform force-unlock LOCK_ID

# Alternative: Delete lock from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "YOUR-BUCKET-NAME/jenkins/dev/terraform.tfstate-md5"}}'
```

## IAM Permissions

### Minimum Permissions for Backend Setup

To run the setup script or create resources manually:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetLifecycleConfiguration",
        "s3:PutLifecycleConfiguration"
      ],
      "Resource": "arn:aws:s3:::terraform-state-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:DescribeContinuousBackups",
        "dynamodb:UpdateContinuousBackups",
        "dynamodb:TagResource"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    },
    {
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}
```

### Minimum Permissions for Terraform Operations

For running `terraform plan` and `terraform apply`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    }
  ]
}
```

## Troubleshooting

### Error: "Failed to get existing workspaces"

**Cause**: S3 bucket doesn't exist or insufficient permissions

**Solution**:
```bash
# Verify bucket exists
aws s3 ls s3://YOUR-BUCKET-NAME

# Check permissions
aws s3api get-bucket-location --bucket YOUR-BUCKET-NAME
```

### Error: "Error acquiring the state lock"

**Cause**: Previous operation was interrupted, leaving a lock

**Solution**:
```bash
# Get lock ID from error message, then force unlock
terraform force-unlock LOCK_ID
```

### Error: "NoSuchBucket: The specified bucket does not exist"

**Cause**: Bucket name in backend.tf doesn't match actual bucket

**Solution**:
```bash
# List your S3 buckets
aws s3 ls

# Update backend.tf with correct bucket name
# Run: terraform init -reconfigure
```

### Error: "DynamoDB table does not exist"

**Cause**: DynamoDB table hasn't been created

**Solution**:
```bash
# Run the setup script
./setup-backend.sh

# Or create table manually (see Manual Setup section)
```

### State File Corruption

**Recovery steps**:

```bash
# 1. List state versions
aws s3api list-object-versions \
  --bucket YOUR-BUCKET-NAME \
  --prefix jenkins/dev/terraform.tfstate

# 2. Download a previous version
aws s3api get-object \
  --bucket YOUR-BUCKET-NAME \
  --key jenkins/dev/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.recovered

# 3. Review recovered state
terraform show terraform.tfstate.recovered

# 4. If good, upload as current version
aws s3 cp terraform.tfstate.recovered \
  s3://YOUR-BUCKET-NAME/jenkins/dev/terraform.tfstate
```

## Security Best Practices

### 1. Never Commit backend.tf with Actual Values

Add to `.gitignore`:
```gitignore
# Terraform backend configuration with actual values
terraform/backend.tf
```

### 2. Use Separate Backends per Environment

```hcl
# Development
key = "jenkins/dev/terraform.tfstate"

# Staging
key = "jenkins/staging/terraform.tfstate"

# Production
key = "jenkins/prod/terraform.tfstate"
```

### 3. Enable MFA Delete on Production Buckets

For production environments, require MFA for state deletion:

```bash
aws s3api put-bucket-versioning \
  --bucket YOUR-PRODUCTION-BUCKET \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::ACCOUNT_ID:mfa/root-account-mfa-device XXXXXX"
```

### 4. Use Separate AWS Accounts

For maximum isolation:
- Development: One AWS account
- Production: Separate AWS account

### 5. Enable CloudTrail Logging

Monitor all S3 and DynamoDB operations:

```bash
aws cloudtrail create-trail \
  --name terraform-state-audit \
  --s3-bucket-name audit-logs-bucket
```

### 6. Regular State Backups

Though S3 versioning provides protection, consider automated backups:

```bash
#!/bin/bash
# backup-state.sh
DATE=$(date +%Y%m%d-%H%M%S)
aws s3 cp \
  s3://YOUR-BUCKET/jenkins/prod/terraform.tfstate \
  s3://backup-bucket/terraform-state-backups/prod-$DATE.tfstate
```

## Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [DynamoDB Point-in-Time Recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)

## Support

If you encounter issues not covered in this document:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Terraform logs: `TF_LOG=DEBUG terraform init`
3. Verify AWS credentials: `aws sts get-caller-identity`
4. Check IAM permissions match requirements
5. Open an issue in the project repository
