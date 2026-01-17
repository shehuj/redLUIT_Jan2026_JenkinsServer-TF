# AWS Credentials Setup for GitHub Actions

## Overview

This repository uses **direct AWS credentials** from GitHub Secrets. No STS (Security Token Service), no OIDC, no role assumption - just simple, straightforward credential usage.

## How It Works

### Workflow Configuration

Both workflows (`terraform-pr.yml` and `terraform-deploy.yml`) use the same credential setup:

```yaml
env:
  TF_LOG: WARN
  TF_IN_AUTOMATION: true
  AWS_REGION: ${{ secrets.AWS_REGION }}
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### What This Means

1. **Credentials set at workflow level** - Available to all jobs and steps
2. **Terraform uses them automatically** - AWS provider reads these env vars
3. **No additional configuration needed** - No aws-actions steps, no STS calls
4. **Simple and reliable** - Direct authentication with AWS

## Required GitHub Secrets

Go to: **Settings > Secrets and variables > Actions > New repository secret**

Add these **three required secrets**:

| Secret Name | Description | Example | Required |
|-------------|-------------|---------|----------|
| `AWS_REGION` | AWS region | `us-east-1` | ✅ YES |
| `AWS_ACCESS_KEY_ID` | IAM user access key | `AKIAIOSFODNN7EXAMPLE` | ✅ YES |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key | `wJalrXUtn...` | ✅ YES |
| `PUBLIC_IP` | Your IP in CIDR | `108.243.221.242/32` | ✅ YES |
| `JENKINS_S3_BUCKET_NAME` | Unique bucket name | `jenkins-artifacts-...` | ✅ YES |

### Optional Secrets

| Secret Name | Default | Description |
|-------------|---------|-------------|
| `ENVIRONMENT` | `prod` | Environment name |
| `JENKINS_UI_CIDRS` | `["0.0.0.0/0"]` | Jenkins UI access CIDRs |

## Creating AWS IAM User

If you don't have an IAM user for Terraform, create one:

### 1. Create IAM User

```bash
aws iam create-user --user-name terraform-github-actions
```

### 2. Create Access Key

```bash
aws iam create-access-key --user-name terraform-github-actions
```

**Save the output!** You'll need:
- `AccessKeyId` → GitHub Secret `AWS_ACCESS_KEY_ID`
- `SecretAccessKey` → GitHub Secret `AWS_SECRET_ACCESS_KEY`

### 3. Attach Policies

For Terraform to work, attach these policies:

```bash
# EC2, VPC, and networking
aws iam attach-user-policy \
  --user-name terraform-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

# S3 for artifacts and state
aws iam attach-user-policy \
  --user-name terraform-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# IAM for roles and instance profiles
aws iam attach-user-policy \
  --user-name terraform-github-actions \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# CloudWatch for logging and alarms
aws iam attach-user-policy \
  --user-name terraform-github-actions \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess

# KMS for encryption
aws iam attach-user-policy \
  --user-name terraform-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser

# DynamoDB for state locking
aws iam attach-user-policy \
  --user-name terraform-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
```

**Note:** These are broad permissions for simplicity. For production, use least-privilege policies.

## How Terraform Uses Credentials

When Terraform runs in the workflow:

1. GitHub Actions sets environment variables from secrets
2. Terraform AWS provider automatically reads:
   - `AWS_REGION`
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Terraform authenticates with AWS using these credentials
4. All Terraform operations use this authentication

**No additional configuration needed in Terraform code!**

## Security Best Practices

### 1. Rotate Credentials Regularly

```bash
# Create new key
aws iam create-access-key --user-name terraform-github-actions

# Update GitHub secrets with new key

# Delete old key (after verifying new one works)
aws iam delete-access-key \
  --user-name terraform-github-actions \
  --access-key-id <OLD_KEY_ID>
```

Rotate every **90 days** or when:
- Team member leaves
- Suspected compromise
- Compliance requirements

### 2. Monitor Usage

Enable CloudTrail to monitor API calls:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=terraform-github-actions
```

### 3. Restrict by IP (Optional)

Add an IAM policy condition to restrict usage to GitHub Actions IPs:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "NotIpAddress": {
        "aws:SourceIp": [
          "192.30.252.0/22",
          "185.199.108.0/22",
          "140.82.112.0/20",
          "143.55.64.0/20"
        ]
      }
    }
  }]
}
```

Note: GitHub Actions IP ranges change, so verify current ranges.

### 4. Use Separate Users per Environment

Best practice: Different IAM users for different environments

```bash
# Development
aws iam create-user --user-name terraform-github-dev

# Production
aws iam create-user --user-name terraform-github-prod
```

Then use different GitHub secrets per environment.

## Troubleshooting

### "No valid credential sources found"

**Cause:** Secrets not configured or named incorrectly

**Fix:**
1. Go to Settings > Secrets and variables > Actions
2. Verify these exist:
   - `AWS_REGION`
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Check spelling matches exactly (case-sensitive)

### "The security token included in the request is invalid"

**Cause:** Secret access key is incorrect or credentials expired

**Fix:**
1. Verify credentials work locally:
   ```bash
   export AWS_ACCESS_KEY_ID="<value from secret>"
   export AWS_SECRET_ACCESS_KEY="<value from secret>"
   export AWS_REGION="us-east-1"
   aws sts get-caller-identity
   ```
2. If that fails, create new access key
3. Update GitHub secret

### "Access Denied" errors

**Cause:** IAM user lacks required permissions

**Fix:**
1. Check which permission is missing from error message
2. Add required policy to IAM user
3. Re-run workflow

### Workflow shows "[secure]" for credentials

**This is normal!** GitHub Actions automatically masks secrets in logs.

You'll see:
```
AWS_ACCESS_KEY_ID: ***
AWS_SECRET_ACCESS_KEY: ***
```

This is **correct security behavior**.

## Testing Credentials

### Test Locally

Before adding to GitHub:

```bash
# Set credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="us-east-1"

# Test they work
aws sts get-caller-identity

# Test Terraform can use them
cd terraform
terraform init
terraform plan
```

### Test in Workflow

Create a minimal test workflow:

```yaml
name: Test AWS Credentials
on: workflow_dispatch

env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test AWS CLI
        run: aws sts get-caller-identity
```

## Why Not Use OIDC/STS?

This setup uses **static credentials** instead of OIDC/STS for simplicity:

**Advantages:**
- ✅ Simpler setup (3 secrets vs complex IAM role configuration)
- ✅ Works immediately (no role trust policy configuration)
- ✅ No external dependencies (no GitHub OIDC provider setup)
- ✅ Easier to troubleshoot (direct authentication)
- ✅ Same approach works locally and in CI

**Trade-offs:**
- ⚠️ Long-lived credentials (mitigated by rotation)
- ⚠️ Stored in GitHub (encrypted at rest)

For most use cases, **static credentials are perfectly fine** when:
- Rotated regularly
- Monitored for unusual activity
- Stored securely in GitHub Secrets

## Alternative: OIDC (Advanced)

If you prefer OIDC (no long-lived credentials):

1. Set up GitHub OIDC provider in AWS
2. Create IAM role with trust policy
3. Use `aws-actions/configure-aws-credentials@v4` with role ARN
4. Remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets

See AWS documentation for OIDC setup.

## Summary

✅ **Simple**: 3 GitHub secrets, works immediately
✅ **Direct**: No STS, no role assumption, no complexity
✅ **Reliable**: Standard AWS credential chain
✅ **Secure**: Encrypted secrets, masked in logs
✅ **Maintainable**: Easy to rotate and update

**Current Setup:**
- Credentials → GitHub Secrets
- Secrets → Workflow env vars
- Env vars → Terraform AWS provider
- ✅ Works!

---

**Last Updated**: 2026-01-17
**Status**: ✅ Production Ready
