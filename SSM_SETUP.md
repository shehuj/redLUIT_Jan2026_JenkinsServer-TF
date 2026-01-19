# AWS Systems Manager (SSM) Access - Quick Start

The jenkinsProject infrastructure now supports AWS Systems Manager Session Manager for secure server access without requiring SSH port 22.

## Why Use SSM?

✅ **No SSH port required** - Works even if your ISP blocks port 22
✅ **Uses HTTPS (port 443)** - Rarely blocked by networks
✅ **No SSH keys needed** - Uses IAM credentials
✅ **Full audit logging** - All sessions logged in CloudTrail
✅ **Encrypted connections** - TLS 1.2+

## Quick Setup

### 1. Install Session Manager Plugin (One-time)

**macOS:**
```bash
brew install --cask session-manager-plugin
```

**Linux:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

**Windows:**
Download from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

**Verify installation:**
```bash
session-manager-plugin --version
```

### 2. Connect to Jenkins Server

**Option A: Using the convenience script**
```bash
./scripts/connect-jenkins-ssm.sh
```

**Option B: Manual connection**
```bash
# Get instance ID from Terraform outputs
cd jenkinsProject/terraform
terraform output jenkins_instance_id

# Connect
aws ssm start-session --target <instance-id>
```

**Example:**
```bash
aws ssm start-session --target i-0e47aba7d2830a4e0
```

## What Changed in the Infrastructure

### Terraform Changes

**1. IAM Role Policy** (`jenkinsProject/terraform/main.tf`)
```hcl
# Added AWS managed policy for SSM access
resource "aws_iam_role_policy_attachment" "jenkins_ssm_policy" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

This policy grants the Jenkins EC2 instance permissions to:
- Register with SSM service
- Send session data
- Retrieve session logs
- Download SSM documents

**2. Output** (`jenkinsProject/terraform/outputs.tf`)
```hcl
output "ssm_connection_command" {
  description = "AWS Systems Manager Session Manager connection command"
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id}"
}
```

**3. Workflow Updates** (`.github/workflows/jenkinsProject-tf.yml`)
- Deployment summary now shows SSM connection command
- SSM connection listed as recommended method

## After Next Deployment

The next time you deploy or update the infrastructure:

1. **Terraform will apply the IAM policy changes**
2. **SSM agent will register automatically** (pre-installed on Ubuntu AMIs)
3. **You can connect within 2-3 minutes**

## Current Instance

For the currently running instance (i-0e47aba7d2830a4e0), you need to:

### Option 1: Update via Terraform (Recommended)

```bash
cd jenkinsProject/terraform

# Initialize
terraform init \
  -backend-config="bucket=$TF_BACKEND_BUCKET" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="dynamodb_table=$TF_DYNAMODB_TABLE"

# Apply changes
terraform apply
```

This will:
- Attach the SSM policy to the IAM role
- No instance restart required
- SSM will be available within 1-2 minutes

### Option 2: Manual IAM Policy Attachment

```bash
# Attach the policy manually
aws iam attach-role-policy \
  --role-name jenkins-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

### Option 3: Via GitHub Actions

Simply trigger a new workflow run:
1. Make a small change (like updating a comment)
2. Push to create a PR
3. Merge to main
4. Infrastructure will update automatically

## Verify SSM Access

After applying changes, verify the instance is registered with SSM:

```bash
# Check SSM agent status
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-0e47aba7d2830a4e0"

# Should show PingStatus: "Online"
```

## Troubleshooting

### SSM agent not connecting

**1. Check IAM role is attached:**
```bash
aws ec2 describe-instances --instance-ids i-0e47aba7d2830a4e0 \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn'
```

**2. Check IAM policy is attached:**
```bash
aws iam list-attached-role-policies --role-name jenkins-ec2-role
```

**3. Wait 2-3 minutes** after applying IAM changes for SSM agent to register

**4. Check instance has internet access** (required for SSM endpoint communication)

### Session Manager plugin not found

```bash
# Verify installation
which session-manager-plugin

# If not found, reinstall
brew reinstall --cask session-manager-plugin  # macOS
```

### "Target not connected" error

The instance needs:
1. IAM instance profile with SSM permissions ✓ (added)
2. SSM agent running (pre-installed on Ubuntu)
3. Internet access to reach SSM endpoints
4. 2-3 minutes for initial registration

## SSH over SSM (Advanced)

If you need actual SSH with key-based authentication:

**1. Start port forwarding:**
```bash
aws ssm start-session \
    --target i-0e47aba7d2830a4e0 \
    --document-name AWS-StartPortForwardingSession \
    --parameters "portNumber=22,localPortNumber=2222"
```

**2. Connect via tunneled port (in another terminal):**
```bash
ssh -i ~/.ssh/key.pem -p 2222 ubuntu@localhost
```

This gives you:
- SSH with your key authentication
- SSH config file usage (~/.ssh/config)
- SCP/rsync over the tunnel
- No port 22 access needed from your network

## Security Benefits

1. **No exposed SSH port** - Can remove port 22 from security group if desired
2. **IAM-based access control** - Use IAM policies to control who can connect
3. **Session logging** - All sessions logged to CloudTrail and S3
4. **MFA support** - Can require MFA for SSM sessions
5. **No key management** - No SSH keys to rotate or secure

## Cost

SSM Session Manager is **free** for standard sessions. Only advanced features (session recording to S3) incur storage costs.

## Next Steps

1. **Install Session Manager plugin** (if not already)
2. **Apply Terraform changes** (next deployment or manual apply)
3. **Wait 2-3 minutes** for SSM registration
4. **Connect:** `./scripts/connect-jenkins-ssm.sh`

## Resources

- [AWS SSM Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Session Manager Plugin Installation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- [IAM Permissions for Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html)
