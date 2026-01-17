# Quick Start Guide

Get your production Jenkins infrastructure running in minutes!

## Prerequisites

- AWS Account with appropriate permissions
- GitHub account with repository access
- Your public IP address

## Setup (One-Time)

### 1. Configure Backend (5 minutes)

```bash
cd terraform
./setup-backend.sh
```

Follow prompts, note the bucket and table names.

### 2. Update backend.tf

Uncomment and update with your values from setup script:

```hcl
terraform {
  backend "s3" {
    bucket         = "YOUR-BUCKET-NAME"
    key            = "jenkins/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "YOUR-TABLE-NAME"
    encrypt        = true
  }
}
```

### 3. Configure GitHub Secrets

Go to **Settings > Secrets and variables > Actions**

Add these secrets:

```
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
PUBLIC_IP=your.ip.address/32
JENKINS_S3_BUCKET_NAME=jenkins-artifacts-unique-name
```

Optional:
```
AWS_REGION=us-east-1
ENVIRONMENT=prod
JENKINS_UI_CIDRS=["your.ip.address/32"]
```

### 4. Configure Production Environment

Go to **Settings > Environments > New environment**

- Name: `production`
- Add required reviewers (team members)
- Restrict to `main` branch only

## Usage

### Making Changes

```bash
# 1. Create branch
git checkout -b feature/my-change

# 2. Make changes
vim terraform/variables.tf

# 3. Commit and push
git add .
git commit -m "feat: my change"
git push origin feature/my-change

# 4. Create PR on GitHub
# → Workflow runs automatically
# → Review plan in PR comments
# → Check security scans
# → Get approval
# → Merge PR

# 5. After merge to main
# → Deployment workflow triggers
# → Approve deployment when prompted
# → Infrastructure deployed
# → Access Jenkins at URL in workflow output
```

### First Deployment

```bash
# After configuring secrets and environment:

# 1. Go to GitHub Actions tab
# 2. Select "Terraform Deploy to Production"
# 3. Click "Run workflow"
# 4. Select branch: main
# 5. Click "Run workflow"
# 6. Wait for approval prompt
# 7. Review plan
# 8. Click "Approve and deploy"
# 9. Get Jenkins URL from workflow output
```

## Access Jenkins

After deployment:

1. **Get URL** from workflow output or:
   ```bash
   cd terraform
   terraform output jenkins_public_ip
   # Visit http://<IP>:8080
   ```

2. **Get initial password**:
   ```bash
   ssh ubuntu@<JENKINS_IP>
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

3. **Complete setup wizard**
   - Enter password
   - Install suggested plugins
   - Create admin user
   - Start using Jenkins!

## Workflows

### On Pull Request
- ✅ Terraform format check
- ✅ Terraform validate
- ✅ Terraform plan (no apply)
- ✅ Security scans (tfsec, Checkov)
- ✅ Cost estimation
- ✅ PR comments with results
- ❌ No infrastructure changes

### On Merge to Main
- ✅ Terraform plan
- ⏸️ **Manual approval required**
- ✅ Terraform apply
- ✅ Deploy to production
- ✅ Output Jenkins URL

## Cost

**Production Configuration**:
- EC2 m5.xlarge: ~$140/month
- Storage & networking: ~$10-20/month
- **Total: ~$150-160/month**

**Free Tier Option**:
- Change `jenkins_instance_type = "t2.micro"` in `terraform.tfvars`
- Cost: $0 (first 12 months)

## Common Commands

```bash
# Format code
terraform fmt -recursive

# Validate locally
terraform validate

# Plan locally
terraform plan

# See what's deployed
terraform output

# Destroy (careful!)
terraform destroy
```

## Documentation

- **Full Deployment**: See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
- **Workflows**: See [WORKFLOWS.md](WORKFLOWS.md)
- **Backend**: See [BACKEND.md](terraform/BACKEND.md)
- **Implementation**: See [IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md)

## Troubleshooting

### "Secrets missing" error
→ Configure GitHub Secrets (step 3 above)

### "Approval required" waiting
→ Go to Actions tab, click deployment, click "Review deployments", approve

### Jenkins not accessible
→ Wait 2-3 minutes for Jenkins to start
→ Check security group allows your IP

### Plan shows unexpected changes
→ Review `terraform plan` output
→ Check if someone else made changes

## Support

- GitHub Issues: https://github.com/YOUR-ORG/YOUR-REPO/issues
- Documentation: See docs above
- Workflows: Check Actions tab for logs

---

**Ready to deploy?** → Configure secrets → Create PR → Merge → Approve → Done! 🚀
