# Jenkins Infrastructure Deployment Guide

This guide walks you through deploying Jenkins infrastructure on AWS using Terraform and Ansible.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Deployment Workflow](#deployment-workflow)
- [Accessing Jenkins](#accessing-jenkins)
- [Destroying Infrastructure](#destroying-infrastructure)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools (Local Development)
- AWS CLI configured with credentials
- Terraform >= 1.6.0
- Ansible (for local testing)
- SSH key pair created in AWS

### GitHub Repository Secrets
Configure these secrets in your GitHub repository (Settings → Secrets → Actions):

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `TF_BACKEND_BUCKET` | S3 bucket for Terraform state | `my-terraform-state-bucket` |
| `TF_DYNAMODB_TABLE` | DynamoDB table for state locking | `terraform-state-lock` |
| `SSH_PRIVATE_KEY` | Private SSH key content | `-----BEGIN RSA PRIVATE KEY-----...` |

## Initial Setup

### 1. Create Backend Infrastructure

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Set your bucket name (must be globally unique)
export BUCKET_NAME="your-unique-terraform-state-bucket"
export REGION="us-east-1"

# Create S3 bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION
```

### 2. Create SSH Key Pair

```bash
# Create key pair in AWS (if not exists)
aws ec2 create-key-pair \
  --key-name key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/jenkins-key.pem

# Set permissions
chmod 400 ~/.ssh/jenkins-key.pem

# Add as GitHub secret: SSH_PRIVATE_KEY
cat ~/.ssh/jenkins-key.pem
```

### 3. Configure Repository Secrets

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret from the table above

## Deployment Workflow

### Automated Deployment (Recommended)

#### For Development (dev workspace)

1. **Create a Pull Request**
   ```bash
   git checkout -b feature/my-changes
   # Make your changes
   git add .
   git commit -m "Add feature"
   git push origin feature/my-changes
   ```

2. **GitHub Actions will:**
   - ✅ Run Terraform Deploy (provisions infrastructure in `dev` workspace)
   - ✅ Run Ansible Check (validates infrastructure is accessible)
   - ❌ Skip Jenkins deployment (PRs are validation-only)

3. **Review the PR**
   - Check the Terraform plan output
   - Verify infrastructure validation passed
   - Review Ansible connectivity tests

#### For Production (prod workspace)

1. **Merge to main**
   ```bash
   git checkout main
   git merge feature/my-changes
   git push origin main
   ```

2. **GitHub Actions will:**
   - ✅ Run Terraform Deploy (provisions infrastructure in `prod` workspace)
   - ✅ Deploy Jenkins with Ansible
   - ✅ Provide Jenkins URL and initial password

### Manual Deployment (Local)

For local testing or manual deployment:

```bash
# 1. Navigate to Terraform directory
cd infra/terraform

# 2. Initialize Terraform
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="key=terraform-states/dev/infra.tfstate"

# 3. Select or create workspace
terraform workspace new dev  # or: terraform workspace select dev

# 4. Review and apply
terraform plan
terraform apply

# 5. Get outputs
terraform output jenkins_public_ip
terraform output jenkins_private_ip

# 6. Run Ansible (optional, for local testing)
cd ../../ansible
ansible-playbook \
  -i inventory/hosts.ini \
  playbooks/deploy_jenkins.yml
```

## Accessing Jenkins

### From GitHub Actions Summary

After successful deployment, check the workflow run summary:

```
## ✅ Jenkins Deployment Complete

### 🔐 Access Information
- Jenkins URL: http://54.123.45.67:8080
- Public IP: 54.123.45.67
- Private IP: 10.1.1.42
- Initial Admin Password: `abc123xyz789`

### 📝 Next Steps
1. Navigate to the Jenkins URL above
2. Use the Initial Admin Password to log in
3. Complete the Jenkins setup wizard
```

### Manual Access

```bash
# Get Jenkins IP
cd infra/terraform
terraform output jenkins_public_ip

# SSH to instance
ssh -i ~/.ssh/jenkins-key.pem ubuntu@$(terraform output -raw jenkins_public_ip)

# Get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Jenkins Setup

1. **Navigate to Jenkins**
   - Open browser: `http://<jenkins_public_ip>:8080`

2. **Unlock Jenkins**
   - Paste the initial admin password
   - Click "Continue"

3. **Install Plugins**
   - Select "Install suggested plugins"
   - Wait for installation to complete

4. **Create Admin User**
   - Fill in your admin user details
   - Click "Save and Continue"

5. **Configure Instance**
   - Verify Jenkins URL
   - Click "Save and Finish"

6. **Start Using Jenkins**
   - Click "Start using Jenkins"

## Destroying Infrastructure

### Via GitHub Actions (Recommended)

1. **Navigate to Actions**
   - Go to your repository
   - Click "Actions" tab
   - Select "Terraform Destroy - Resource Cleanup"

2. **Run Workflow**
   - Click "Run workflow"
   - Select workspace (`dev` or `prod`)
   - Type `DESTROY` in confirmation field
   - Provide reason for destruction
   - Click "Run workflow"

3. **Monitor Progress**
   - Watch the workflow execute
   - Review pre-destroy inventory
   - Approve if production environment is configured
   - Check final verification

### Manual Destroy (Local)

```bash
cd infra/terraform

# Select workspace
terraform workspace select dev  # or prod

# Destroy infrastructure
terraform destroy

# Verify all resources are gone
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=Terraform" \
  --query 'Reservations[*].Instances[*].InstanceId'
```

## Workflow Details

### Terraform Deploy Workflow

**Triggers:**
- Pull request to `main` or `dev`
- Push to `main` or `dev`
- Changes to `infra/terraform/**` or workflow file

**Workspaces:**
- `dev` branch → `dev` workspace
- `main` branch → `prod` workspace

**Steps:**
1. Terraform init with remote backend
2. Terraform validate
3. Terraform plan
4. Terraform apply
5. Capture outputs (IPs, instance ID)

### Ansible Configuration Workflow

**Triggers:**
- After successful Terraform Deploy
- Manual trigger with `workflow_dispatch`

**Jobs:**

1. **check-infrastructure** (PR only)
   - Validates Terraform outputs exist
   - Tests SSH connectivity
   - Tests Ansible connectivity
   - Does NOT deploy Jenkins

2. **deploy-jenkins** (main branch only)
   - Retrieves Terraform outputs
   - Builds dynamic Ansible inventory
   - Deploys Jenkins
   - Retrieves initial password

## Troubleshooting

### Terraform Issues

**Workspace already exists error:**
```bash
# This is now fixed with idempotent workspace handling
# The workflow automatically selects existing workspaces
```

**No outputs found:**
```bash
# Ensure infrastructure was deployed
cd infra/terraform
terraform workspace select dev
terraform output

# If no outputs, resources weren't created
terraform apply
```

### Ansible Issues

**SSH connection refused:**
```bash
# Verify security group allows SSH from your IP
# Check if EC2 instance is running
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=Terraform" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]'
```

**Ansible can't connect:**
```bash
# Test SSH manually
ssh -i ~/.ssh/jenkins-key.pem ubuntu@<jenkins_ip>

# Verify SSH key secret is correct
# Ensure security group allows port 22
```

### Jenkins Access Issues

**Can't access Jenkins UI:**
```bash
# Verify Jenkins is running
ssh -i ~/.ssh/jenkins-key.pem ubuntu@<jenkins_ip>
sudo systemctl status jenkins

# Check logs
sudo journalctl -u jenkins -f

# Verify security group allows port 8080
```

**Lost initial password:**
```bash
# SSH to instance and retrieve password
ssh -i ~/.ssh/jenkins-key.pem ubuntu@<jenkins_ip>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Security Best Practices

### Production Checklist

- [ ] Restrict SSH access to specific IPs in `terraform.tfvars`
- [ ] Use GitHub environments with required reviewers
- [ ] Enable MFA for AWS accounts
- [ ] Rotate SSH keys regularly
- [ ] Review security group rules
- [ ] Enable VPC Flow Logs (optional)
- [ ] Set up CloudWatch monitoring
- [ ] Configure Jenkins security realm
- [ ] Enable HTTPS with SSL certificate
- [ ] Regular security updates

### Recommended terraform.tfvars Changes

```hcl
# Get your IP
# curl -s https://checkip.amazonaws.com

ssh_allowed_cidrs = ["YOUR_IP/32"]  # Replace with your actual IP
```

## Cost Optimization

### Estimated Monthly Costs (us-east-1)

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| EC2 (t3.micro) | 730 hours/month | ~$7.50 |
| EBS (20GB gp3) | Storage | ~$1.60 |
| S3 (state) | Minimal usage | ~$0.10 |
| DynamoDB | On-demand | ~$0.05 |
| Data Transfer | Minimal | ~$0.50 |
| **Total** | | **~$10/month** |

### Cost Saving Tips

1. **Use Spot Instances** (not recommended for Jenkins)
2. **Stop EC2 when not in use**
   ```bash
   aws ec2 stop-instances --instance-ids <instance-id>
   ```
3. **Destroy dev environment when not needed**
4. **Use Elastic IPs** (if frequent stop/start)

## Support and Contribution

### Getting Help

- Check [Troubleshooting](#troubleshooting) section
- Review GitHub Actions workflow logs
- Check AWS CloudWatch logs

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.
