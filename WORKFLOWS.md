# GitHub Actions Workflows Documentation

This document explains the CI/CD workflows for the Jenkins Terraform infrastructure.

## Table of Contents

- [Overview](#overview)
- [Workflow Architecture](#workflow-architecture)
- [Pull Request Workflow](#pull-request-workflow)
- [Deployment Workflow](#deployment-workflow)
- [Setup Instructions](#setup-instructions)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

The repository uses a **two-workflow architecture**:

1. **`terraform-pr.yml`** - Runs on pull requests to validate changes
2. **`terraform-deploy.yml`** - Deploys to production on merge to main

This separation ensures:
- ✅ All changes are validated before merging
- ✅ Infrastructure is only modified on main branch
- ✅ Security scans run on every change
- ✅ Manual approval required for production deployments
- ✅ Clear audit trail of all infrastructure changes

---

## Workflow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Pull Request Workflow                       │
│                    (terraform-pr.yml)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────┐        │
│  │  Validate    │  │  Security   │  │  Cost          │        │
│  │  & Plan      │  │  Scanning   │  │  Estimation    │        │
│  │              │  │             │  │                │        │
│  │ • Format     │  │ • tfsec     │  │ • Resource     │        │
│  │ • Validate   │  │ • Checkov   │  │   counts       │        │
│  │ • Plan       │  │ • SARIF     │  │ • Monthly cost │        │
│  │ • Comment PR │  │   upload    │  │ • Comment PR   │        │
│  └──────────────┘  └─────────────┘  └────────────────┘        │
│                                                                  │
│  No infrastructure changes are made                             │
└─────────────────────────────────────────────────────────────────┘

                            ↓ Merge to main ↓

┌─────────────────────────────────────────────────────────────────┐
│                    Deployment Workflow                           │
│                  (terraform-deploy.yml)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │  Plan        │                                               │
│  │              │                                               │
│  │ • Validate   │                                               │
│  │ • Plan       │                                               │
│  │ • Upload     │                                               │
│  └──────┬───────┘                                               │
│         │                                                        │
│         ↓                                                        │
│  ┌──────────────┐                                               │
│  │  Deploy      │  ⚠️  Requires manual approval                │
│  │              │                                               │
│  │ • Download   │  Environment: production                      │
│  │   plan       │  Reviewers: [configured]                      │
│  │ • Apply      │  Wait: [optional]                             │
│  │ • Outputs    │                                               │
│  └──────┬───────┘                                               │
│         │                                                        │
│         ↓                                                        │
│  ┌──────────────┐                                               │
│  │  Notify      │                                               │
│  │              │                                               │
│  │ • Summary    │                                               │
│  │ • Status     │                                               │
│  └──────────────┘                                               │
│                                                                  │
│  Infrastructure changes applied to production                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Pull Request Workflow

**File**: `.github/workflows/terraform-pr.yml`

**Triggered by**: Opening or updating a pull request that changes:
- `terraform/**`
- `.github/workflows/terraform-pr.yml`
- `.github/workflows/terraform-deploy.yml`

### Jobs

#### 1. Validate & Plan

**Purpose**: Validate Terraform code and generate plan

**Steps**:
1. **Format Check** - Ensures code follows Terraform style guide
2. **Init** - Initializes Terraform with backend
3. **Validate** - Validates syntax and configuration
4. **Plan** - Generates execution plan
5. **Summary** - Counts resources to add/change/destroy
6. **Comment PR** - Posts plan details as PR comment
7. **Upload Artifact** - Saves plan for review

**Outputs**: PR comment with plan details and resource counts

#### 2. Security Scanning

**Purpose**: Scan for security vulnerabilities and compliance issues

**Steps**:
1. **tfsec** - Security scanning for Terraform
   - Checks for misconfigurations
   - Validates security best practices
   - Fails on MEDIUM or higher severity
2. **Checkov** - Compliance scanning
   - Checks against policy frameworks
   - Validates compliance requirements
   - Soft fail (reports but doesn't block)
3. **Upload SARIF** - Uploads results to GitHub Security tab

**Outputs**: Security scan results in Security tab

#### 3. Cost Estimation

**Purpose**: Estimate monthly infrastructure costs

**Steps**:
1. **Calculate** - Estimates based on resource types
2. **Comment PR** - Posts cost estimate as PR comment

**Outputs**: PR comment with cost breakdown

### PR Comment Example

```markdown
## Terraform Plan Results 📋

#### Format Check: `success`
#### Initialization: `success`
#### Validation: `success`
#### Plan: `success`

### Summary
- **22** resources to add
- **0** resources to change
- **0** resources to destroy

<details><summary>Show Full Plan</summary>

... (full plan output)

</details>

---
💰 Cost Estimation: ~$152-162/month
```

---

## Deployment Workflow

**File**: `.github/workflows/terraform-deploy.yml`

**Triggered by**:
- Push to `main` branch (after PR merge)
- Manual workflow dispatch

### Jobs

#### 1. Plan Deployment

**Purpose**: Generate deployment plan before applying

**Steps**:
1. **AWS Auth** - Configure credentials
2. **Create tfvars** - Generate from secrets
3. **Init** - Initialize Terraform
4. **Validate** - Validate configuration
5. **Plan** - Generate deployment plan
6. **Upload** - Save plan and output

**Outputs**: Plan artifact for deployment job

#### 2. Deploy to Production

**Purpose**: Apply infrastructure changes

**Environment**: `production` (requires manual approval)

**Steps**:
1. **Wait for Approval** - GitHub shows approval UI
2. **AWS Auth** - Configure credentials
3. **Create tfvars** - Generate from secrets
4. **Init** - Initialize Terraform
5. **Download Plan** - Get plan from previous job
6. **Apply** - Execute approved plan
7. **Get Outputs** - Retrieve Jenkins URL and IP
8. **Summary** - Post deployment details

**Outputs**: Jenkins URL and deployment summary

#### 3. Notify

**Purpose**: Send deployment status notifications

**Steps**:
1. **Status Check** - Verify deployment success
2. **Notification** - Log final status

---

## Setup Instructions

### 1. Configure GitHub Secrets

Go to: **Settings > Secrets and variables > Actions > New repository secret**

#### Required Secrets

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key for Terraform | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `PUBLIC_IP` | Your IP in CIDR format | `203.0.113.42/32` |
| `JENKINS_S3_BUCKET_NAME` | Unique S3 bucket name | `jenkins-artifacts-mycompany-prod` |

#### Optional Secrets (with defaults)

| Secret Name | Default | Description |
|-------------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region |
| `ENVIRONMENT` | `prod` | Environment name |
| `JENKINS_UI_CIDRS` | `["0.0.0.0/0"]` | Jenkins UI access CIDRs (JSON array) |

### 2. Create Production Environment

Go to: **Settings > Environments > New environment**

**Name**: `production`

#### Protection Rules

Enable these protections:

1. **Required reviewers**
   - Add team members who must approve deployments
   - Minimum: 1 reviewer
   - Recommended: 2+ reviewers for production

2. **Wait timer** (optional)
   - Add delay before deployment
   - Example: 5 minutes
   - Allows time for final checks

3. **Deployment branches**
   - Select "Selected branches"
   - Add `main` branch only
   - Prevents deployments from feature branches

4. **Environment secrets** (optional)
   - Override repository secrets for production
   - Use production-specific values

### 3. Enable Security Scanning

Go to: **Settings > Code security and analysis**

Enable:
- ✅ Dependency graph
- ✅ Dependabot alerts
- ✅ Code scanning (for SARIF uploads)

### 4. Configure Branch Protection

Go to: **Settings > Branches > Add rule**

**Branch name pattern**: `main`

Enable:
- ✅ Require a pull request before merging
- ✅ Require approvals (1+)
- ✅ Require status checks to pass
  - Add: `Validate & Plan`
  - Add: `Security Scanning`
- ✅ Require conversation resolution
- ✅ Do not allow bypassing the above settings

---

## Usage Examples

### Making Infrastructure Changes

```bash
# 1. Create feature branch
git checkout -b feature/add-monitoring

# 2. Make changes
vim terraform/main.tf

# 3. Commit changes
git add terraform/
git commit -m "feat: add CloudWatch dashboard"

# 4. Push and create PR
git push origin feature/add-monitoring

# Go to GitHub and create Pull Request
```

**What happens**:
1. ✅ PR workflow runs automatically
2. ✅ Terraform plan posted as comment
3. ✅ Security scans run
4. ✅ Cost estimate added
5. ✅ Review plan and security results
6. ✅ Request review from team
7. ✅ Merge when approved

**After merge**:
1. ✅ Deployment workflow triggers
2. ⏸️ Waits for approval (if configured)
3. ✅ Deploy to production
4. ✅ Receive Jenkins URL

### Manual Deployment

For urgent deployments or rollbacks:

1. Go to **Actions** tab
2. Select **Terraform Deploy to Production**
3. Click **Run workflow**
4. Select branch: `main`
5. Choose action: `apply` or `destroy`
6. Click **Run workflow**
7. Approve when prompted

### Viewing Deployment History

**GitHub UI**:
- Go to **Actions** tab
- Filter by workflow
- Click on run to see details

**Deployments**:
- Go to **Code** tab
- Click **Environments** (right sidebar)
- Select `production`
- View deployment history

---

## Troubleshooting

### PR Workflow Issues

#### "Format check failed"

**Cause**: Code doesn't follow Terraform style

**Fix**:
```bash
cd terraform
terraform fmt -recursive
git add .
git commit -m "fix: format terraform code"
git push
```

#### "Security scan failed"

**Cause**: tfsec found security issues

**Fix**:
1. Check Security tab for details
2. Review and fix issues
3. Push changes
4. Re-run workflow

#### "Plan failed"

**Cause**: Terraform validation errors

**Fix**:
1. Review error in workflow logs
2. Fix configuration issues
3. Run locally: `terraform validate`
4. Push fixes

### Deployment Workflow Issues

#### "Missing secrets"

**Cause**: Required secrets not configured

**Fix**:
1. Go to Settings > Secrets
2. Add missing secrets
3. Re-run workflow

#### "Approval timeout"

**Cause**: No one approved within timeout period

**Fix**:
1. Notify reviewers
2. Wait for approval
3. Workflow continues automatically

#### "Apply failed"

**Cause**: Various (check logs)

**Fix**:
1. Review error in workflow logs
2. Check AWS console for details
3. Fix issue
4. Re-run workflow or revert changes

### Common Errors

#### "Error acquiring state lock"

**Cause**: Previous workflow still running or crashed

**Fix**:
```bash
# Check for running workflows
# Cancel if stuck

# Or force unlock (use carefully)
terraform force-unlock <LOCK_ID>
```

#### "Backend initialization failed"

**Cause**: S3 bucket or DynamoDB table doesn't exist

**Fix**:
```bash
cd terraform
./setup-backend.sh
# Update backend.tf if needed
```

---

## Best Practices

### Pull Requests

1. **Small, focused PRs** - Easier to review and validate
2. **Clear descriptions** - Explain what and why
3. **Review plan carefully** - Check resource counts and changes
4. **Address security issues** - Fix before merging
5. **Get peer review** - Don't merge your own PRs

### Deployments

1. **Deploy during business hours** - Team available if issues arise
2. **Monitor deployments** - Watch workflow progress
3. **Verify after deployment** - Check Jenkins is accessible
4. **Communicate** - Notify team of major deployments
5. **Have rollback plan** - Know how to revert changes

### Security

1. **Rotate secrets regularly** - Update every 90 days
2. **Limit reviewer access** - Only trusted team members
3. **Review security scans** - Don't ignore warnings
4. **Use least privilege** - Minimal IAM permissions
5. **Audit deployments** - Review deployment history regularly

---

## Workflow Comparison

| Feature | PR Workflow | Deployment Workflow |
|---------|-------------|---------------------|
| **Trigger** | Pull request | Merge to main |
| **Purpose** | Validate changes | Deploy changes |
| **Format check** | ✅ Yes | ✅ Yes |
| **Validation** | ✅ Yes | ✅ Yes |
| **Plan** | ✅ Yes | ✅ Yes |
| **Apply** | ❌ No | ✅ Yes |
| **Security scan** | ✅ Yes | ❌ No* |
| **Cost estimate** | ✅ Yes | ❌ No |
| **Approval required** | ❌ No | ✅ Yes |
| **Infrastructure changed** | ❌ No | ✅ Yes |

\* Security scans run on PR, not on deployment (changes already validated)

---

## Maintenance

### Updating Workflows

To update workflows:

1. Create PR with workflow changes
2. Test in feature branch (if possible)
3. Review carefully - workflows control deployments
4. Merge when validated

### Adding New Environments

To add staging/development environments:

1. Create new environment in GitHub
2. Add environment-specific secrets
3. Update workflow to support environment selection
4. Test thoroughly before using

### Monitoring

Regular checks:

- **Weekly**: Review failed workflows
- **Monthly**: Audit deployment history
- **Quarterly**: Review and rotate secrets
- **Annually**: Review and update approval requirements

---

## Support

For issues:

1. Check [Troubleshooting](#troubleshooting) section
2. Review workflow logs in Actions tab
3. Check Security tab for scan results
4. Review `DEPLOYMENT-GUIDE.md` for setup issues
5. Open issue in repository

---

## Changelog

### 2026-01-17
- ✅ Split into separate PR and deployment workflows
- ✅ Added comprehensive validation on PRs
- ✅ Added manual approval for production deployments
- ✅ Added cost estimation
- ✅ Fixed SARIF upload issues
- ✅ Updated to CodeQL Action v4

---

**Documentation Version**: 1.0
**Last Updated**: 2026-01-17
**Maintained by**: DevOps Team
