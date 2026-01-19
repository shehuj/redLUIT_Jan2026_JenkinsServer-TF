# JenkinsProject - Infrastructure & Configuration

This directory contains Terraform and Ansible configurations for deploying a Jenkins server on AWS with S3 artifact storage.

## Architecture

### Infrastructure Components

1. **EC2 Instance**
   - Ubuntu 22.04 LTS
   - Instance Type: m5.xlarge (configurable)
   - Encrypted EBS root volume (20GB gp3)
   - IMDSv2 enabled for enhanced security
   - Attached IAM instance profile for S3 access

2. **S3 Bucket for Artifacts**
   - Private bucket (all public access blocked)
   - AES256 server-side encryption enabled
   - Versioning enabled for artifact history
   - Lifecycle policy:
     - Current artifacts: Deleted after 180 days
     - Non-current versions: Deleted after 90 days

3. **Security Group**
   - Port 22: SSH access (configurable CIDR blocks)
   - Port 8080: Jenkins web interface (0.0.0.0/0)
   - Port 443: HTTPS for future use (0.0.0.0/0)
   - Egress: Allow all outbound traffic

4. **IAM Configuration**
   - IAM Role: `jenkins-ec2-role`
   - Instance Profile: `jenkins-instance-profile`
   - Permissions: Full S3 access to artifacts bucket (PutObject, GetObject, DeleteObject, ListBucket)

## Deployment Workflow

### On Pull Request
1. **Terraform Deploy** workflow runs
2. Infrastructure provisioned (EC2, S3, IAM, Security Group)
3. Outputs displayed (IPs, bucket name)
4. Infrastructure validated and ready

### On Merge to Main
1. **Ansible Configuration** workflow runs
2. Retrieves infrastructure details from Terraform state
3. Installs and configures Jenkins
4. Displays initial admin password and access information

## Configuration Variables

Edit `terraform/variables.tf` to customize:

```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "m5.xlarge"
}

variable "key_pair" {
  default = "key"  # Your AWS SSH key pair name
}

variable "ssh_allowed_cidrs" {
  default = ["0.0.0.0/0"]  # Restrict to your IP in production
}

variable "artifacts_bucket_name" {
  default = "jenkinsproject-artifacts-bucket"  # Must be globally unique
}
```

## Configuring Jenkins to Use S3

After Jenkins is deployed, configure it to use the S3 bucket for artifact storage:

### Option 1: S3 Artifact Manager Plugin

1. **Install S3 Artifact Manager Plugin**
   - Navigate to: Manage Jenkins → Manage Plugins → Available
   - Search for "Artifact Manager on S3"
   - Install and restart Jenkins

2. **Configure S3 Storage**
   - Navigate to: Manage Jenkins → Configure System
   - Find "Artifact Management for Builds" section
   - Select "Amazon S3"
   - Bucket name: `jenkinsproject-artifacts-bucket` (or your custom name)
   - Region: `us-east-1` (or your configured region)
   - Use IAM instance profile: ✓ (enabled by default, EC2 instance has necessary permissions)

### Option 2: S3 Publisher Plugin

1. **Install S3 Plugin**
   - Navigate to: Manage Jenkins → Manage Plugins → Available
   - Search for "S3 publisher plugin"
   - Install and restart Jenkins

2. **Configure in Job**
   - In your Jenkins job configuration
   - Add post-build action: "Publish artifacts to S3 Bucket"
   - Bucket name: `jenkinsproject-artifacts-bucket`
   - Region: `us-east-1`
   - Use IAM Role: ✓

### Verify IAM Permissions

The EC2 instance has an attached IAM instance profile with these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::jenkinsproject-artifacts-bucket",
        "arn:aws:s3:::jenkinsproject-artifacts-bucket/*"
      ]
    }
  ]
}
```

Jenkins can automatically use these credentials via the AWS SDK without additional configuration.

## Outputs

After deployment, the following information is available:

- **jenkins_public_ip**: Public IP for web access and SSH
- **jenkins_private_ip**: Private IP within VPC
- **jenkins_instance_id**: EC2 instance identifier
- **jenkins_security_group_id**: Security group ID
- **jenkins_artifacts_bucket_name**: S3 bucket name for artifacts
- **jenkins_artifacts_bucket_arn**: S3 bucket ARN
- **jenkins_iam_role_arn**: IAM role ARN

Access outputs via:
```bash
cd terraform
terraform output
```

Or download from GitHub Actions artifacts after workflow run.

## Accessing Jenkins

### Web Interface
```
http://<jenkins_public_ip>:8080
```

### Server Access

#### Option 1: AWS Systems Manager Session Manager (Recommended)

**Why use SSM?**
- No SSH port 22 required
- Works even if your ISP blocks SSH
- Uses HTTPS (port 443) - rarely blocked
- Full audit logging in CloudTrail
- No SSH keys needed

**Prerequisites:**
```bash
# Install Session Manager plugin (one-time setup)
# macOS with Homebrew:
brew install --cask session-manager-plugin

# Or download from:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
```

**Connect to Jenkins server:**
```bash
aws ssm start-session --target <jenkins_instance_id>
```

**SSH over SSM (if you need key-based auth):**
```bash
# Start port forwarding
aws ssm start-session \
    --target <jenkins_instance_id> \
    --document-name AWS-StartPortForwardingSession \
    --parameters "portNumber=22,localPortNumber=2222"

# In another terminal, connect via the tunnel
ssh -i ~/.ssh/key.pem -p 2222 ubuntu@localhost
```

#### Option 2: Direct SSH Access
```bash
ssh -i ~/.ssh/key.pem ubuntu@<jenkins_public_ip>
```

**Note:** Requires port 22 to be accessible from your location. If your ISP/network blocks SSH, use SSM instead.

### Initial Admin Password
Retrieved automatically during deployment and displayed in workflow output and artifacts.

Or retrieve manually:
```bash
ssh -i ~/.ssh/key.pem ubuntu@<jenkins_public_ip>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Security Best Practices

### Production Recommendations

1. **Restrict SSH Access**
   ```hcl
   ssh_allowed_cidrs = ["YOUR_IP/32"]
   ```

2. **Use Custom Bucket Name**
   - S3 bucket names must be globally unique
   - Use organization/project prefix: `myorg-jenkins-artifacts`

3. **Enable CloudWatch Monitoring**
   - Consider enabling detailed EC2 monitoring
   - Set up CloudWatch alarms for disk usage, CPU

4. **Regular Backups**
   - Jenkins configuration in `/var/lib/jenkins`
   - Consider backup plugin or scheduled snapshots

5. **SSL/TLS Certificate**
   - Add SSL certificate for HTTPS access
   - Use AWS Certificate Manager + ALB/NLB
   - Or configure nginx reverse proxy with Let's Encrypt

6. **VPC Configuration**
   - Currently uses default VPC
   - For production, deploy in custom VPC with private subnets
   - Use bastion host or VPN for SSH access

## Cost Estimate (us-east-1)

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| EC2 (m5.xlarge) | 730 hours/month | ~$140 |
| EBS (20GB gp3) | Storage + IOPS | ~$2 |
| S3 Storage | Variable usage | ~$0.02/GB |
| Data Transfer | Minimal | ~$1 |
| **Total** | | **~$143-150/month** |

**Note**: Costs vary based on:
- Actual instance uptime
- S3 storage usage
- Data transfer volumes
- Additional AWS services used

## Troubleshooting

### SSH Connection Refused
- Check security group allows your IP (port 22)
- Verify EC2 instance is running: `aws ec2 describe-instances --instance-ids <id>`
- Ensure correct SSH key is used

### Jenkins Not Accessible on Port 8080
- Check Jenkins service: `sudo systemctl status jenkins`
- View logs: `sudo journalctl -u jenkins -f`
- Verify security group allows port 8080

### S3 Access Denied
- Verify IAM instance profile is attached to EC2
- Check IAM policy has correct bucket name
- Ensure bucket exists in same region

### Terraform State Locked
- Check DynamoDB table for lock entries
- If stale lock: `terraform force-unlock <lock-id>`

## Cleanup

### Destroy Infrastructure
Use the GitHub Actions workflow "Terraform Destroy - Resource Cleanup":
1. Go to Actions → Terraform Destroy
2. Click "Run workflow"
3. Select workspace: `dev`
4. Type "DESTROY" to confirm
5. Provide reason for destruction
6. Run workflow

Or manually:
```bash
cd terraform
terraform destroy
```

**Warning**: This will:
- Terminate EC2 instance
- Delete S3 bucket (including all artifacts - ensure you have backups!)
- Delete security group
- Delete IAM role and instance profile

## Support

For issues or questions:
- Check workflow logs in GitHub Actions
- Review AWS CloudWatch logs
- Check Terraform state: `terraform show`

## License

MIT License
