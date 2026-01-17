# Complete Infrastructure Deployment Guide

This guide will walk you through deploying the Jenkins infrastructure from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Step 1: Backend Setup](#step-1-backend-setup)
4. [Step 2: Configuration](#step-2-configuration)
5. [Step 3: Terraform Initialization](#step-3-terraform-initialization)
6. [Step 4: Deployment](#step-4-deployment)
7. [Step 5: Verification](#step-5-verification)
8. [Step 6: GitHub CI/CD Setup (Optional)](#step-6-github-cicd-setup-optional)
9. [Troubleshooting](#troubleshooting)
10. [Cleanup](#cleanup)

---

## Prerequisites

### Required Tools

1. **AWS CLI** (v2.x or higher)
   ```bash
   aws --version
   # Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   ```

2. **Terraform** (v1.0 or higher)
   ```bash
   terraform version
   # Install: https://developer.hashicorp.com/terraform/downloads
   ```

3. **jq** (for JSON parsing)
   ```bash
   jq --version
   # macOS: brew install jq
   # Ubuntu: sudo apt-get install jq
   # Amazon Linux: sudo yum install jq
   ```

### AWS Setup

1. **AWS Account** with appropriate permissions
2. **AWS Credentials** configured
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Access Key, Region, Output format
   ```

3. **Verify credentials**
   ```bash
   aws sts get-caller-identity
   # Should show your account ID, user ARN, and user ID
   ```

### Required Information

Gather the following before starting:

- ✅ Your **public IP address** (in CIDR format)
  ```bash
  # Get your public IP
  curl ifconfig.me
  # Convert to CIDR: <IP>/32 (e.g., 203.0.113.42/32)
  ```

- ✅ **Unique S3 bucket name** for Jenkins artifacts
  - Must be globally unique
  - 3-63 characters, lowercase, no underscores
  - Example: `jenkins-artifacts-mycompany-dev-2026`

- ✅ **AWS Region** (e.g., `us-east-1`)

- ✅ **Environment name** (e.g., `dev`, `staging`, `prod`)

---

## Pre-Deployment Checklist

Before proceeding, ensure:

- [ ] AWS CLI is installed and configured
- [ ] Terraform is installed
- [ ] jq is installed
- [ ] You have your public IP address
- [ ] You have chosen a unique S3 bucket name
- [ ] You have chosen an AWS region
- [ ] You have AWS credentials with necessary permissions
- [ ] You're in the project directory

---

## Step 1: Backend Setup

The backend stores Terraform state remotely in S3 with DynamoDB for state locking.

### Option A: Automated Setup (Recommended)

```bash
cd terraform

# Run the setup script
./setup-backend.sh

# Or with custom values
./setup-backend.sh \
  --bucket my-terraform-state-bucket \
  --table my-terraform-lock-table \
  --region us-east-1 \
  --profile default
```

The script will:
1. Create S3 bucket with versioning and encryption
2. Block public access to the bucket
3. Create DynamoDB table for state locking
4. Enable point-in-time recovery
5. Print configuration values for backend.tf

**Save the output!** You'll need the bucket and table names.

### Option B: Manual Setup

If you prefer manual setup, follow the instructions in `BACKEND.md`.

### Configure backend.tf

After running the setup script:

1. Open `terraform/backend.tf`
2. Uncomment the `terraform` block (lines 49-76)
3. Update with your actual values:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-123456789012-us-east-1"  # From setup script
    key            = "jenkins/dev/terraform.tfstate"
    region         = "us-east-1"                               # Your region
    dynamodb_table = "terraform-state-lock"                    # From setup script
    encrypt        = true
  }
}
```

4. Save the file

---

## Step 2: Configuration

### Create terraform.tfvars

```bash
cd terraform

# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars  # or vim, code, etc.
```

### Required Configuration

Update `terraform.tfvars` with your actual values:

```hcl
# =============================================================================
# REQUIRED - Update these values
# =============================================================================

# Your AWS region
aws_region = "us-east-1"

# Your public IP in CIDR format (for SSH access)
# Get it: curl ifconfig.me
public_ip = "203.0.113.42/32"  # ← UPDATE THIS

# Unique S3 bucket name for Jenkins artifacts
jenkins_s3_bucket_name = "jenkins-artifacts-mycompany-dev-2026"  # ← UPDATE THIS

# Environment name
environment = "dev"

# =============================================================================
# CRITICAL SECURITY DECISION
# =============================================================================

# Jenkins UI Access - Who can access Jenkins on port 8080?
# OPTION 1 (Recommended): Your IP only
jenkins_ui_cidrs = ["203.0.113.42/32"]  # ← UPDATE THIS

# OPTION 2 (For testing only): Open to internet - NOT SECURE!
# jenkins_ui_cidrs = ["0.0.0.0/0"]

# =============================================================================
# OPTIONAL - Customize as needed
# =============================================================================

# Instance type (t2.micro is free tier eligible)
jenkins_instance_type = "t2.small"

# Jenkins port
jenkins_port = 8080

# Additional SSH access (empty = only your IP)
allowed_ssh_cidrs = []

# Security features (auto-enabled for prod)
enable_kms_encryption      = false
enable_detailed_monitoring = false
enable_backup              = false

# S3 lifecycle - delete old artifacts after N days
s3_lifecycle_expiration_days = 90

# CloudWatch log retention
cloudwatch_retention_days = 30

# Root volume size (GB)
root_volume_size = 30

# Tags
tags = {
  Project    = "Jenkins CI/CD"
  Owner      = "DevOps Team"
  CostCenter = "Engineering"
}
```

### Important Security Notes

⚠️ **Never commit terraform.tfvars to version control!**

Add to `.gitignore`:
```bash
echo "terraform/terraform.tfvars" >> .gitignore
```

---

## Step 3: Terraform Initialization

### Initialize Terraform

```bash
cd terraform

# Initialize Terraform (downloads providers, sets up backend)
terraform init

# If you have local state and want to migrate to remote:
terraform init -migrate-state
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "s3"!

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Verify Backend

```bash
# Check that state will be stored remotely
terraform show

# Verify S3 bucket (should be empty initially)
aws s3 ls s3://YOUR-BUCKET-NAME/jenkins/dev/
```

---

## Step 4: Deployment

### Format and Validate

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

### Plan the Deployment

```bash
# Generate and review execution plan
terraform plan

# Save plan to file for review
terraform plan -out=tfplan
```

Review the plan carefully. You should see:
- **S3 bucket** for artifacts
- **IAM role** and instance profile
- **Security groups** for SSH and Jenkins UI
- **EC2 instance** for Jenkins
- **CloudWatch** log group
- All resources properly tagged

### Apply the Configuration

```bash
# Deploy the infrastructure
terraform apply

# Or use the saved plan
terraform apply tfplan
```

When prompted, type `yes` to confirm.

**Expected duration:** 3-5 minutes

### Monitor Deployment

Watch the output for:
1. S3 bucket creation
2. IAM resources creation
3. Security group creation
4. EC2 instance launch
5. CloudWatch resources setup

---

## Step 5: Verification

### Get Outputs

```bash
# Display all outputs
terraform output

# Get specific values
terraform output jenkins_public_ip
terraform output jenkins_url
terraform output s3_bucket_name
```

### Access Jenkins

1. **Get the Jenkins URL:**
   ```bash
   echo "http://$(terraform output -raw jenkins_public_ip):8080"
   ```

2. **Open in browser** (may take 2-3 minutes for Jenkins to start)

3. **Get initial admin password:**
   ```bash
   # SSH into the instance
   ssh -i <your-key>.pem ec2-user@$(terraform output -raw jenkins_public_ip)

   # Get the password
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

4. **Complete Jenkins setup wizard:**
   - Enter the initial admin password
   - Install suggested plugins
   - Create admin user
   - Configure Jenkins URL

### Verify S3 Bucket

```bash
# List bucket
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/

# Check bucket configuration
aws s3api get-bucket-versioning --bucket $(terraform output -raw s3_bucket_name)
aws s3api get-bucket-encryption --bucket $(terraform output -raw s3_bucket_name)
```

### Verify Security Groups

```bash
# Get security group ID
terraform output security_group_id

# Check ingress rules
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id) \
  --query 'SecurityGroups[0].IpPermissions'
```

You should see:
- SSH (port 22) from your IP
- HTTP (port 8080) from your configured CIDR

### Verify IAM Permissions

```bash
# Get IAM role name
terraform output iam_role_name

# Check attached policies
aws iam list-attached-role-policies \
  --role-name $(terraform output -raw iam_role_name)

# View policy document
aws iam get-role-policy \
  --role-name $(terraform output -raw iam_role_name) \
  --policy-name jenkins-dev-s3-policy
```

Should show least-privilege S3 permissions (8 specific actions, not s3:*).

### Test Jenkins Build

1. Create a test freestyle project
2. Add build step: "Execute shell"
   ```bash
   echo "Hello from Jenkins!"
   date
   aws s3 ls s3://YOUR-BUCKET-NAME/ || echo "S3 access test"
   ```
3. Build the project
4. Check console output

---

## Step 6: GitHub CI/CD Setup (Optional)

To enable automated deployments via GitHub Actions:

### Configure GitHub Secrets

Go to: `Settings > Secrets and variables > Actions`

Add these secrets:

**Required:**
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
- `AWS_REGION` - e.g., `us-east-1`
- `PUBLIC_IP` - e.g., `203.0.113.42/32`
- `JENKINS_S3_BUCKET_NAME` - Your bucket name
- `ENVIRONMENT` - e.g., `dev`
- `JENKINS_UI_CIDRS` - e.g., `["203.0.113.42/32"]`

**Optional (for OIDC):**
- `AWS_ROLE_ARN` - IAM role ARN for OIDC authentication

### Configure GitHub Environments

1. Go to: `Settings > Environments`

2. Create **production** environment:
   - Click "New environment"
   - Name: `production`
   - Add protection rules:
     - ✅ Required reviewers (add team members)
     - ✅ Wait timer: 5 minutes (optional)
     - ✅ Deployment branches: `main` only

3. Create **development** environment:
   - Name: `development`
   - No protection rules needed

### Enable Security Scanning

Go to: `Settings > Code security and analysis`

Enable:
- ✅ Dependency graph
- ✅ Dependabot alerts
- ✅ Code scanning (for SARIF uploads)

### Test the Workflow

```bash
# Make a change
echo "# Test" >> README.md

# Commit and push
git add .
git commit -m "test: trigger CI/CD workflow"
git push origin main
```

Check: `Actions` tab to see the workflow run.

---

## Troubleshooting

### Common Issues

#### 1. "Error acquiring the state lock"

**Cause:** Previous operation was interrupted

**Solution:**
```bash
# Get lock ID from error message, then:
terraform force-unlock <LOCK_ID>
```

#### 2. "Bucket already exists"

**Cause:** Bucket name is not unique globally

**Solution:**
```bash
# Choose a different bucket name in terraform.tfvars
jenkins_s3_bucket_name = "jenkins-artifacts-mycompany-dev-$(date +%s)"
```

#### 3. "Invalid CIDR block"

**Cause:** Incorrect IP format

**Solution:**
```bash
# Must be in CIDR notation with /32 for single IP
public_ip = "203.0.113.42/32"  # Correct
public_ip = "203.0.113.42"      # Wrong - missing /32
```

#### 4. Jenkins not accessible

**Cause:** Instance still booting or security group misconfigured

**Solution:**
```bash
# Check instance status
aws ec2 describe-instance-status \
  --instance-ids $(terraform output -raw jenkins_instance_id)

# Check security group
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id)

# Check user data logs
ssh ec2-user@$(terraform output -raw jenkins_public_ip)
sudo tail -f /var/log/cloud-init-output.log
```

#### 5. "No valid credential sources found"

**Cause:** AWS credentials not configured

**Solution:**
```bash
# Configure AWS credentials
aws configure

# Verify
aws sts get-caller-identity
```

#### 6. Terraform plan shows changes on every run

**Cause:** Should not happen anymore (we removed timestamp())

**Solution:**
```bash
# Check what's changing
terraform plan

# If CreatedDate shows, ensure you have latest code
git pull origin main
```

### Getting Help

1. Check `BACKEND.md` for backend-specific issues
2. Check `IMPLEMENTATION-SUMMARY.md` for what was changed
3. Review GitHub Actions logs in the `Actions` tab
4. Check AWS CloudWatch logs for EC2 issues
5. Review Terraform state: `terraform show`

---

## Cleanup

### Destroy Infrastructure

When you're done testing:

```bash
cd terraform

# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy
```

Type `yes` when prompted.

**Note:** This will NOT destroy the backend (S3 bucket and DynamoDB table). To remove those:

```bash
# Empty the S3 bucket first
aws s3 rm s3://YOUR-BUCKET-NAME --recursive

# Delete the bucket
aws s3 rb s3://YOUR-BUCKET-NAME

# Delete DynamoDB table
aws dynamodb delete-table --table-name YOUR-TABLE-NAME
```

### Partial Cleanup

To destroy only specific resources:

```bash
# Destroy only the EC2 instance
terraform destroy -target=module.jenkins.aws_instance.this

# Destroy only the S3 bucket (will fail if not empty)
terraform destroy -target=module.jenkins.aws_s3_bucket.artifacts
```

---

## Post-Deployment Best Practices

### Security

1. **Rotate credentials regularly**
   - Update AWS access keys every 90 days
   - Update Jenkins admin password

2. **Review IAM permissions**
   - Audit quarterly
   - Remove unused permissions

3. **Monitor security scans**
   - Check GitHub Security tab weekly
   - Address vulnerabilities promptly

4. **Enable MFA**
   - For AWS root account
   - For AWS IAM users
   - For Jenkins admin users

### Monitoring

1. **Set up CloudWatch alarms**
   ```bash
   # CPU usage alert
   aws cloudwatch put-metric-alarm \
     --alarm-name jenkins-high-cpu \
     --alarm-description "Alert when CPU exceeds 80%" \
     --metric-name CPUUtilization \
     --namespace AWS/EC2 \
     --statistic Average \
     --period 300 \
     --threshold 80 \
     --comparison-operator GreaterThanThreshold
   ```

2. **Review logs regularly**
   ```bash
   # Jenkins logs
   aws logs tail /aws/ec2/jenkins-dev --follow

   # System logs
   ssh ec2-user@<jenkins-ip> sudo journalctl -u jenkins -f
   ```

### Backup

1. **Verify S3 versioning**
   ```bash
   aws s3api get-bucket-versioning --bucket <bucket-name>
   ```

2. **Test state recovery**
   ```bash
   # List state versions
   aws s3api list-object-versions \
     --bucket <bucket-name> \
     --prefix jenkins/dev/terraform.tfstate
   ```

3. **Backup Jenkins configuration**
   - Use Jenkins backup plugins
   - Store in separate S3 bucket
   - Test restore procedure

### Cost Optimization

1. **Review costs**
   ```bash
   # Check current month costs
   aws ce get-cost-and-usage \
     --time-period Start=2026-01-01,End=2026-01-31 \
     --granularity MONTHLY \
     --metrics BlendedCost
   ```

2. **Right-size instances**
   - Monitor CPU/memory usage
   - Downsize if under-utilized
   - Use t3 instances for better performance

3. **Lifecycle policies**
   - Already configured for S3
   - Adjust retention as needed

---

## Success Metrics

After deployment, verify:

- ✅ Jenkins accessible via browser
- ✅ Can SSH into EC2 instance
- ✅ S3 bucket created with encryption
- ✅ IAM permissions use least privilege
- ✅ Security groups restrict access appropriately
- ✅ CloudWatch logs receiving data
- ✅ State stored remotely in S3
- ✅ DynamoDB state locking works
- ✅ All resources properly tagged
- ✅ No perpetual drift on terraform plan

---

## Quick Reference

### Common Commands

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy everything
terraform destroy

# Show current state
terraform show

# List all resources
terraform state list

# Get outputs
terraform output

# Refresh state
terraform refresh

# Import existing resource
terraform import <resource_type>.<name> <resource_id>
```

### AWS CLI Quick Reference

```bash
# Check S3 bucket
aws s3 ls s3://<bucket-name>

# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=Jenkins"

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=Jenkins"

# Check IAM roles
aws iam list-roles | grep jenkins

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/ec2/jenkins
```

---

## Next Steps

1. Configure Jenkins:
   - Install required plugins
   - Set up build agents
   - Configure SCM connections
   - Create build pipelines

2. Integrate with services:
   - GitHub/GitLab webhooks
   - Slack notifications
   - JIRA integration
   - SonarQube

3. Enhance security:
   - Enable HTTPS with Let's Encrypt
   - Configure SAML/LDAP authentication
   - Set up audit logging
   - Implement secrets management

4. Scale:
   - Add Jenkins agents
   - Configure auto-scaling
   - Set up multi-region deployment
   - Implement blue-green deployments

---

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review `BACKEND.md` for backend issues
3. Review `IMPLEMENTATION-SUMMARY.md` for recent changes
4. Check GitHub Issues in the repository
5. Review Terraform and AWS documentation

---

**Happy building! 🚀**
