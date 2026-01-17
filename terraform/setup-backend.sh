#!/bin/bash

# ========================================================================
# Terraform Backend Setup Script
# ========================================================================
#
# This script creates the required AWS resources for Terraform remote state:
# - S3 bucket for state storage (with versioning, encryption, and public access block)
# - DynamoDB table for state locking (with point-in-time recovery)
#
# Prerequisites:
# - AWS CLI installed and configured
# - Appropriate IAM permissions (see BACKEND.md)
# - jq installed (for JSON parsing)
#
# Usage:
#   ./setup-backend.sh [options]
#
# Options:
#   -b, --bucket NAME       S3 bucket name (default: terraform-state-<account-id>-<region>)
#   -t, --table NAME        DynamoDB table name (default: terraform-state-lock)
#   -r, --region REGION     AWS region (default: us-east-1)
#   -p, --profile PROFILE   AWS profile (default: default)
#   -h, --help              Show this help message
#
# ========================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-default}"
S3_BUCKET=""
DYNAMODB_TABLE="terraform-state-lock"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--bucket)
      S3_BUCKET="$2"
      shift 2
      ;;
    -t|--table)
      DYNAMODB_TABLE="$2"
      shift 2
      ;;
    -r|--region)
      AWS_REGION="$2"
      shift 2
      ;;
    -p|--profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Functions
print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
check_prerequisites() {
  print_info "Checking prerequisites..."

  if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
  fi

  if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it first."
    exit 1
  fi

  print_success "All prerequisites installed"
}

# Get AWS account ID
get_account_id() {
  aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text 2>/dev/null || {
    print_error "Failed to get AWS account ID. Check your AWS credentials."
    exit 1
  }
}

# Generate default bucket name if not provided
generate_bucket_name() {
  if [ -z "$S3_BUCKET" ]; then
    ACCOUNT_ID=$(get_account_id)
    S3_BUCKET="terraform-state-${ACCOUNT_ID}-${AWS_REGION}"
    print_info "Using generated bucket name: $S3_BUCKET"
  fi
}

# Create S3 bucket
create_s3_bucket() {
  print_info "Creating S3 bucket: $S3_BUCKET in region $AWS_REGION..."

  # Check if bucket already exists
  if aws s3api head-bucket --bucket "$S3_BUCKET" --profile "$AWS_PROFILE" 2>/dev/null; then
    print_warning "S3 bucket already exists: $S3_BUCKET"
    return 0
  fi

  # Create bucket (special handling for us-east-1)
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" || {
      print_error "Failed to create S3 bucket"
      exit 1
    }
  else
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" || {
      print_error "Failed to create S3 bucket"
      exit 1
    }
  fi

  print_success "S3 bucket created successfully"
}

# Enable S3 bucket versioning
enable_bucket_versioning() {
  print_info "Enabling versioning on S3 bucket..."

  aws s3api put-bucket-versioning \
    --bucket "$S3_BUCKET" \
    --profile "$AWS_PROFILE" \
    --versioning-configuration Status=Enabled || {
    print_error "Failed to enable versioning"
    exit 1
  }

  print_success "Versioning enabled"
}

# Enable S3 bucket encryption
enable_bucket_encryption() {
  print_info "Enabling encryption on S3 bucket..."

  aws s3api put-bucket-encryption \
    --bucket "$S3_BUCKET" \
    --profile "$AWS_PROFILE" \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          },
          "BucketKeyEnabled": true
        }
      ]
    }' || {
    print_error "Failed to enable encryption"
    exit 1
  }

  print_success "Encryption enabled (AES256)"
}

# Block public access to S3 bucket
block_public_access() {
  print_info "Blocking public access to S3 bucket..."

  aws s3api put-public-access-block \
    --bucket "$S3_BUCKET" \
    --profile "$AWS_PROFILE" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" || {
    print_error "Failed to block public access"
    exit 1
  }

  print_success "Public access blocked"
}

# Add bucket lifecycle policy for old versions
add_lifecycle_policy() {
  print_info "Adding lifecycle policy to clean up old versions..."

  aws s3api put-bucket-lifecycle-configuration \
    --bucket "$S3_BUCKET" \
    --profile "$AWS_PROFILE" \
    --lifecycle-configuration '{
      "Rules": [
        {
          "Id": "DeleteOldVersions",
          "Status": "Enabled",
          "NoncurrentVersionExpiration": {
            "NoncurrentDays": 90
          }
        }
      ]
    }' || {
    print_warning "Failed to add lifecycle policy (non-critical)"
  }

  print_success "Lifecycle policy configured (90-day retention for old versions)"
}

# Create DynamoDB table
create_dynamodb_table() {
  print_info "Creating DynamoDB table: $DYNAMODB_TABLE in region $AWS_REGION..."

  # Check if table already exists
  if aws dynamodb describe-table \
    --table-name "$DYNAMODB_TABLE" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" &>/dev/null; then
    print_warning "DynamoDB table already exists: $DYNAMODB_TABLE"
    return 0
  fi

  # Create table
  aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Project,Value=Jenkins Key=ManagedBy,Value=Terraform || {
    print_error "Failed to create DynamoDB table"
    exit 1
  }

  print_success "DynamoDB table created successfully"

  # Wait for table to be active
  print_info "Waiting for table to become active..."
  aws dynamodb wait table-exists \
    --table-name "$DYNAMODB_TABLE" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" || {
    print_error "Failed waiting for table"
    exit 1
  }

  print_success "Table is active"
}

# Enable point-in-time recovery for DynamoDB
enable_pitr() {
  print_info "Enabling point-in-time recovery for DynamoDB table..."

  aws dynamodb update-continuous-backups \
    --table-name "$DYNAMODB_TABLE" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true || {
    print_warning "Failed to enable point-in-time recovery (non-critical)"
    return 0
  }

  print_success "Point-in-time recovery enabled"
}

# Print next steps
print_next_steps() {
  echo ""
  echo -e "${GREEN}========================================================================${NC}"
  echo -e "${GREEN}Backend Setup Complete!${NC}"
  echo -e "${GREEN}========================================================================${NC}"
  echo ""
  echo "Resources created:"
  echo "  • S3 Bucket: $S3_BUCKET"
  echo "  • DynamoDB Table: $DYNAMODB_TABLE"
  echo "  • Region: $AWS_REGION"
  echo ""
  echo "Next steps:"
  echo ""
  echo "1. Update backend.tf with these values:"
  echo ""
  echo "   terraform {"
  echo "     backend \"s3\" {"
  echo "       bucket         = \"$S3_BUCKET\""
  echo "       key            = \"jenkins/dev/terraform.tfstate\""
  echo "       region         = \"$AWS_REGION\""
  echo "       dynamodb_table = \"$DYNAMODB_TABLE\""
  echo "       encrypt        = true"
  echo "     }"
  echo "   }"
  echo ""
  echo "2. Uncomment the backend block in backend.tf"
  echo ""
  echo "3. Initialize Terraform:"
  echo "   cd terraform"
  echo "   terraform init -migrate-state"
  echo ""
  echo "4. Verify state is stored remotely:"
  echo "   aws s3 ls s3://$S3_BUCKET/jenkins/dev/"
  echo ""
  echo "For more information, see BACKEND.md"
  echo ""
}

# Main execution
main() {
  echo -e "${BLUE}========================================================================${NC}"
  echo -e "${BLUE}Terraform Backend Setup${NC}"
  echo -e "${BLUE}========================================================================${NC}"
  echo ""

  check_prerequisites
  generate_bucket_name

  echo ""
  echo "Configuration:"
  echo "  AWS Profile: $AWS_PROFILE"
  echo "  AWS Region: $AWS_REGION"
  echo "  S3 Bucket: $S3_BUCKET"
  echo "  DynamoDB Table: $DYNAMODB_TABLE"
  echo ""

  # Confirm before proceeding
  read -p "Proceed with setup? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 0
  fi

  echo ""

  # S3 bucket setup
  create_s3_bucket
  enable_bucket_versioning
  enable_bucket_encryption
  block_public_access
  add_lifecycle_policy

  echo ""

  # DynamoDB table setup
  create_dynamodb_table
  enable_pitr

  # Print next steps
  print_next_steps
}

# Run main function
main
