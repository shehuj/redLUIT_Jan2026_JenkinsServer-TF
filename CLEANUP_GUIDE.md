# Resource Cleanup Guide

This guide explains how to safely destroy all AWS infrastructure created by this project.

## Overview

The cleanup workflow (`terraform-destroy.yml`) is a manually-triggered GitHub Actions workflow that:
- ✅ Safely destroys all Terraform-managed resources
- ✅ Empties S3 buckets before deletion
- ✅ Verifies cleanup completion
- ✅ Cleans up orphaned resources
- ✅ Requires explicit confirmation to prevent accidents

## How to Trigger Cleanup

### Method 1: GitHub UI (Recommended)

1. **Navigate to Actions Tab**
   - Go to your repository on GitHub
   - Click the "Actions" tab

2. **Select the Destroy Workflow**
   - In the left sidebar, click "Terraform Destroy - Resource Cleanup"

3. **Run the Workflow**
   - Click the "Run workflow" button (top right)
   - Fill in the required inputs:
     - **Confirmation**: Type exactly `DESTROY` (case-sensitive)
     - **Reason**: Explain why you're destroying the infrastructure
   - Click "Run workflow"

4. **Monitor Progress**
   - Watch the workflow run in real-time
   - Review the summary for details on what was destroyed

### Method 2: GitHub CLI

```bash
gh workflow run terraform-destroy.yml \
  -f confirmation=DESTROY \
  -f reason="Your reason here"
```

### Method 3: REST API

```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/actions/workflows/terraform-destroy.yml/dispatches \
  -d '{
    "ref": "main",
    "inputs": {
      "confirmation": "DESTROY",
      "reason": "Your reason here"
    }
  }'
```

## Workflow Stages

### Stage 1: Validation
- Validates that you typed "DESTROY" correctly
- Logs the destruction request with timestamp and reason
- **Fails fast** if confirmation doesn't match

### Stage 2: Pre-Destroy Inventory
- Lists all current infrastructure:
  - EC2 instances
  - S3 buckets
  - VPCs and subnets
  - Security groups
- Creates a snapshot of resources before deletion
- Useful for verification and audit trail

### Stage 3: Destroy Infrastructure
- Empties all S3 buckets (including versioned objects)
- Runs `terraform destroy` with auto-approve
- Uploads destroy plan as artifact
- Shows detailed output in workflow summary

### Stage 4: Post-Destroy Verification
- Checks that resources were actually deleted:
  - ✅ EC2 instances terminated
  - ✅ VPCs removed
  - ✅ S3 buckets deleted
- Reports any remaining resources

### Stage 5: Orphaned Resources Cleanup
- Cleans up resources that Terraform might have missed:
  - Network interfaces in "available" state
  - Unattached security groups
  - Available EBS volumes
- Ensures complete cleanup

## What Gets Destroyed

### Terraform-Managed Resources
- **VPC**: Including subnets, route tables, internet gateway
- **EC2 Instance**: Jenkins server instance
- **Security Group**: SSH and Jenkins port access rules
- **IAM Role**: Jenkins S3 access role and instance profile
- **S3 Bucket**: Jenkins artifacts bucket (emptied first)
- **KMS Key**: If encryption was enabled

### Additional Cleanup
- All objects in S3 buckets (including versions)
- Orphaned network interfaces
- Unused security groups
- Unattached EBS volumes

## Safety Features

### 1. Manual Trigger Only
- Cannot be triggered automatically
- Requires explicit human action

### 2. Confirmation Required
- Must type "DESTROY" exactly
- Prevents accidental triggers
- Typos will fail the workflow

### 3. Reason Documentation
- Must provide a reason for destruction
- Creates audit trail
- Helps team understand why infrastructure was removed

### 4. Environment Protection
- Uses "production" environment
- Can add additional reviewers in GitHub settings
- Can require manual approval before destruction

### 5. State Preservation
- Terraform state file remains in S3 backend
- Allows recovery if needed
- Can be manually deleted later

## Post-Cleanup Steps

After the workflow completes:

### 1. Verify in AWS Console
- Check EC2 dashboard for terminated instances
- Verify VPC was deleted
- Confirm S3 buckets are gone
- Review CloudWatch logs if needed

### 2. Clean Up Terraform Backend (Optional)
If you want to completely remove all traces:

```bash
# List state files in backend bucket
aws s3 ls s3://YOUR-BACKEND-BUCKET/terraform/

# Delete state file
aws s3 rm s3://YOUR-BACKEND-BUCKET/terraform/terraform.tfstate

# If using DynamoDB for locking
aws dynamodb delete-table --table-name YOUR-LOCK-TABLE

# Delete backend bucket (if no longer needed)
aws s3 rb s3://YOUR-BACKEND-BUCKET --force
```

### 3. Remove Local State (if any)
```bash
cd terraform
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*
```

## Troubleshooting

### Problem: "Resources still exist after destroy"

**Solution:**
1. Check the Post-Destroy Verification section in workflow summary
2. Note any remaining resource IDs
3. Manually delete them via AWS Console or CLI:
   ```bash
   # Terminate EC2 instance
   aws ec2 terminate-instances --instance-ids i-xxxxx

   # Delete VPC (delete subnets first)
   aws ec2 delete-subnet --subnet-id subnet-xxxxx
   aws ec2 delete-vpc --vpc-id vpc-xxxxx

   # Delete S3 bucket
   aws s3 rb s3://bucket-name --force
   ```

### Problem: "Cannot delete VPC - has dependencies"

**Solution:**
Delete dependencies in this order:
1. EC2 instances
2. NAT gateways
3. Network interfaces
4. Security groups (except default)
5. Subnets
6. Route tables (except main)
7. Internet gateway
8. VPC

```bash
# Detach and delete internet gateway
aws ec2 detach-internet-gateway --internet-gateway-id igw-xxxxx --vpc-id vpc-xxxxx
aws ec2 delete-internet-gateway --internet-gateway-id igw-xxxxx

# Delete subnets
aws ec2 delete-subnet --subnet-id subnet-xxxxx

# Delete VPC
aws ec2 delete-vpc --vpc-id vpc-xxxxx
```

### Problem: "S3 bucket not empty"

**Solution:**
The workflow should handle this, but if it fails:
```bash
# Empty bucket (including versions)
aws s3api delete-objects --bucket BUCKET_NAME \
  --delete "$(aws s3api list-object-versions --bucket BUCKET_NAME \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

# Delete bucket
aws s3 rb s3://BUCKET_NAME --force
```

### Problem: "Permission denied during destroy"

**Solution:**
1. Verify AWS credentials are valid
2. Check IAM permissions include:
   - `ec2:*`
   - `s3:*`
   - `iam:DeleteRole*`
   - `vpc:*`
3. Ensure no resource-based policies blocking deletion

## Cost Considerations

Running this workflow:
- **Free**: Workflow execution (within GitHub Actions limits)
- **Free**: API calls to list resources
- **Free**: Deletion operations (AWS doesn't charge for deletes)

After cleanup:
- **Zero ongoing costs**: All billable resources removed
- **Backend costs only**: If keeping Terraform state in S3 (pennies/month)

## Recovery

If you need to recreate the infrastructure after cleanup:

```bash
# Just run the deployment workflow again
gh workflow run terraform-deploy.yml
```

Or merge a PR to trigger automatic deployment.

The state file in S3 backend will be recreated automatically.

## Best Practices

1. **Always provide a clear reason** for destruction
2. **Screenshot the Pre-Destroy Inventory** for records
3. **Download destroy artifacts** before they expire (7 days)
4. **Verify cleanup** in AWS Console after workflow completes
5. **Document in team chat** when destroying shared infrastructure
6. **Check for backups** if any data needs to be preserved
7. **Update documentation** if this is a permanent removal

## Emergency Contacts

If issues occur during cleanup:
- **AWS Support**: [AWS Console Support Center](https://console.aws.amazon.com/support/home)
- **GitHub Support**: [GitHub Support](https://support.github.com)
- **Team Lead**: [Add your team contact here]

## Audit Trail

Every destruction is logged with:
- Timestamp (UTC)
- GitHub actor (who triggered it)
- Reason provided
- Full list of destroyed resources
- Verification results

Workflow run history is retained for 90 days in GitHub Actions.
