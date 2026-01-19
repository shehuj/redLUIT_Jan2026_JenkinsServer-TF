#!/bin/bash
# Local cleanup script for JenkinsProject infrastructure
# This script can be run locally to destroy all JenkinsProject resources

set -e

echo "🧹 JenkinsProject Cleanup Tool"
echo "======================================="
echo ""
echo "⚠️  WARNING: This will DESTROY all JenkinsProject infrastructure!"
echo ""
echo "This includes:"
echo "  - EC2 instance (jenkins-server)"
echo "  - S3 bucket (jenkinsproject-artifacts-bucket)"
echo "  - Security group (jenkinsProject-sg)"
echo "  - IAM role (jenkins-ec2-role)"
echo "  - IAM instance profile"
echo "  - All Jenkins data and artifacts"
echo ""

# Confirmation
read -p "Type 'DESTROY' to confirm: " CONFIRMATION
if [ "$CONFIRMATION" != "DESTROY" ]; then
    echo "❌ Confirmation failed. Exiting."
    exit 1
fi

read -p "Reason for destruction: " REASON
echo ""
echo "Proceeding with destruction..."
echo "Reason: $REASON"
echo ""

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install it first."
    exit 1
fi

# Check if required secrets are set
if [ -z "$TF_BACKEND_BUCKET" ] || [ -z "$AWS_REGION" ] || [ -z "$TF_DYNAMODB_TABLE" ]; then
    echo "⚠️  Backend configuration environment variables not set."
    echo ""
    read -p "Enter S3 backend bucket name: " TF_BACKEND_BUCKET
    read -p "Enter AWS region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    read -p "Enter DynamoDB table name: " TF_DYNAMODB_TABLE
    echo ""
fi

# Navigate to terraform directory
cd "$(dirname "$0")/../jenkinsProject/terraform" || exit 1

echo "======================================="
echo "Step 1: Initialize Terraform"
echo "======================================="
echo ""

terraform init \
    -backend-config="bucket=$TF_BACKEND_BUCKET" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=$TF_DYNAMODB_TABLE"

echo ""
echo "======================================="
echo "Step 2: Show Current Resources"
echo "======================================="
echo ""

terraform show || echo "No resources found in state"

echo ""
echo "======================================="
echo "Step 3: Empty S3 Bucket"
echo "======================================="
echo ""

# Get bucket name from Terraform
BUCKET_NAME=$(terraform output -raw jenkins_artifacts_bucket_name 2>/dev/null || echo "")

if [ ! -z "$BUCKET_NAME" ]; then
    echo "🪣 Emptying S3 bucket: $BUCKET_NAME"

    # Check if bucket exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        # Count objects
        OBJECT_COUNT=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --query 'length(Versions)' --output text 2>/dev/null || echo "0")
        echo "Found $OBJECT_COUNT object versions"

        if [ "$OBJECT_COUNT" -gt 0 ]; then
            # Delete all object versions
            echo "Deleting object versions..."
            aws s3api list-object-versions \
                --bucket "$BUCKET_NAME" \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output text | while read key version; do
                    if [ ! -z "$key" ]; then
                        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" || true
                    fi
            done

            # Delete all delete markers
            echo "Deleting delete markers..."
            aws s3api list-object-versions \
                --bucket "$BUCKET_NAME" \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
                --output text | while read key version; do
                    if [ ! -z "$key" ]; then
                        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" || true
                    fi
            done

            echo "✅ S3 bucket emptied"
        else
            echo "✅ S3 bucket is already empty"
        fi
    else
        echo "⚠️  S3 bucket does not exist or not accessible"
    fi
else
    echo "⚠️  No S3 bucket found in Terraform outputs"
fi

echo ""
echo "======================================="
echo "Step 4: Destroy Terraform Resources"
echo "======================================="
echo ""

terraform destroy -auto-approve

echo ""
echo "======================================="
echo "Step 5: Cleanup Orphaned Resources"
echo "======================================="
echo ""

# Clean up orphaned IAM resources
IAM_ROLE="jenkins-ec2-role"
INSTANCE_PROFILE="jenkins-instance-profile"

echo "Checking for orphaned IAM resources..."

# Delete instance profile
if aws iam get-instance-profile --instance-profile-name "$INSTANCE_PROFILE" 2>/dev/null; then
    echo "Found orphaned instance profile: $INSTANCE_PROFILE"

    # Remove role from instance profile
    aws iam remove-role-from-instance-profile \
        --instance-profile-name "$INSTANCE_PROFILE" \
        --role-name "$IAM_ROLE" 2>/dev/null || true

    # Delete instance profile
    aws iam delete-instance-profile --instance-profile-name "$INSTANCE_PROFILE" 2>/dev/null || true
    echo "✅ Instance profile deleted"
else
    echo "✅ No orphaned instance profile found"
fi

# Delete IAM role
if aws iam get-role --role-name "$IAM_ROLE" 2>/dev/null; then
    echo "Found orphaned IAM role: $IAM_ROLE"

    # Detach managed policies
    aws iam list-attached-role-policies --role-name "$IAM_ROLE" \
        --query 'AttachedPolicies[].PolicyArn' --output text | while read policy_arn; do
            if [ ! -z "$policy_arn" ]; then
                echo "Detaching policy: $policy_arn"
                aws iam detach-role-policy --role-name "$IAM_ROLE" --policy-arn "$policy_arn" || true
            fi
    done

    # Delete inline policies
    aws iam list-role-policies --role-name "$IAM_ROLE" \
        --query 'PolicyNames[]' --output text | while read policy_name; do
            if [ ! -z "$policy_name" ]; then
                echo "Deleting inline policy: $policy_name"
                aws iam delete-role-policy --role-name "$IAM_ROLE" --policy-name "$policy_name" || true
            fi
    done

    # Delete role
    aws iam delete-role --role-name "$IAM_ROLE" || true
    echo "✅ IAM role deleted"
else
    echo "✅ No orphaned IAM role found"
fi

echo ""
echo "======================================="
echo "Step 6: Verify Complete Cleanup"
echo "======================================="
echo ""

ALL_CLEAN=true

# Check EC2 instances
echo "Checking EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=JenkinsProject" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)

if [ -z "$INSTANCES" ]; then
    echo "✅ No EC2 instances remaining"
else
    echo "⚠️  Found remaining instances: $INSTANCES"
    ALL_CLEAN=false
fi

# Check security groups
echo "Checking security groups..."
SGS=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Project,Values=JenkinsProject" \
    --query 'SecurityGroups[*].GroupId' \
    --output text)

if [ -z "$SGS" ]; then
    echo "✅ No security groups remaining"
else
    echo "⚠️  Found remaining security groups: $SGS"
    ALL_CLEAN=false
fi

# Check S3 buckets
echo "Checking S3 buckets..."
BUCKETS=$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, 'jenkinsproject-artifacts')].Name" \
    --output text)

if [ -z "$BUCKETS" ]; then
    echo "✅ No S3 buckets remaining"
else
    echo "⚠️  Found remaining buckets: $BUCKETS"
    ALL_CLEAN=false
fi

# Check IAM roles
echo "Checking IAM roles..."
if aws iam get-role --role-name jenkins-ec2-role 2>/dev/null; then
    echo "⚠️  Found remaining IAM role: jenkins-ec2-role"
    ALL_CLEAN=false
else
    echo "✅ No IAM roles remaining"
fi

echo ""
echo "======================================="
if [ "$ALL_CLEAN" = true ]; then
    echo "✅ CLEANUP COMPLETE"
    echo "======================================="
    echo ""
    echo "All JenkinsProject infrastructure has been destroyed."
else
    echo "⚠️  CLEANUP COMPLETE (WITH WARNINGS)"
    echo "======================================="
    echo ""
    echo "Some resources could not be automatically deleted."
    echo "Please review the warnings above and manually delete if needed."
fi

echo ""
echo "Reason: $REASON"
echo "Completed at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""
echo "📝 Notes:"
echo "  - Terraform state file remains in S3 backend"
echo "  - Backend infrastructure (S3, DynamoDB) is NOT destroyed"
echo "  - To remove state: Delete 'jenkinsProject/terraform.tfstate' from backend"
echo ""
