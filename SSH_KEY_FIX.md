# SSH Key Fix for GitHub Actions

## Problem Fixed

The GitHub Actions workflow was failing with:
```
Load key "/home/runner/.ssh/key.pem": error in libcrypto
ubuntu@13.216.1.139: Permission denied (publickey).
```

## Root Cause

The SSH private key stored in GitHub Secrets was in **OpenSSH format** instead of the traditional **RSA format**, which causes compatibility issues with some SSH clients.

## Solutions Applied

### 1. Automatic Key Conversion

Updated `.github/workflows/terraform-deploy.yml` to automatically detect and convert OpenSSH format keys to RSA format:

```yaml
# Check and convert key format if needed
if head -n 1 ~/.ssh/key.pem | grep -q "BEGIN OPENSSH PRIVATE KEY"; then
  echo "Converting OpenSSH format to RSA format..."
  ssh-keygen -p -N "" -m pem -f ~/.ssh/key.pem
fi
```

### 2. SSH Agent Setup

Added `ssh-agent` to manage the key properly:

```yaml
# Start ssh-agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/key.pem
```

### 3. Full Path in Ansible Inventory

Changed from `~/.ssh/key.pem` to `$HOME/.ssh/key.pem` for better compatibility:

```yaml
ansible_ssh_private_key_file=$HOME/.ssh/key.pem
```

### 4. Connection Testing

Added test steps before running Ansible:
- SSH connection test
- Ansible ping test

This provides better error messages if there are still issues.

## How to Fix Your SSH Key in GitHub Secrets

### Option 1: Let the Workflow Handle It (Recommended)

The workflow will now automatically convert your key. Just commit and push the updated workflow file.

### Option 2: Convert Your Key Manually (More Reliable)

If you want to ensure the key is in the correct format:

```bash
# 1. Download your key from GitHub Secrets or AWS
# Let's say it's named jenkins-key.pem

# 2. Check current format
head -n 1 jenkins-key.pem

# 3. If it shows "BEGIN OPENSSH PRIVATE KEY", convert it:
ssh-keygen -p -N "" -m pem -f jenkins-key.pem

# 4. Verify conversion
head -n 1 jenkins-key.pem
# Should now show: -----BEGIN RSA PRIVATE KEY-----

# 5. Update GitHub Secret
cat jenkins-key.pem
# Copy the entire output and update SSH_PRIVATE_KEY secret
```

### Option 3: Generate a New Key in RSA Format

```bash
# Generate new RSA key (not OpenSSH format)
ssh-keygen -t rsa -b 4096 -m PEM -f jenkins-key-new.pem -N ""

# This creates:
# - jenkins-key-new.pem (private key) - add to GitHub Secrets
# - jenkins-key-new.pem.pub (public key) - add to AWS EC2 Key Pairs

# Import to AWS
aws ec2 import-key-pair \
  --key-name jenkins-server-key \
  --public-key-material fileb://jenkins-key-new.pem.pub \
  --region us-east-1
```

## Verification Steps

After updating the workflow:

1. **Commit and push changes:**
   ```bash
   git add .github/workflows/terraform-deploy.yml
   git commit -m "Fix SSH key handling in GitHub Actions workflow"
   git push
   ```

2. **Monitor the workflow:**
   - Go to GitHub → Actions tab
   - Watch the workflow run
   - The "Configure SSH Key" step should show:
     - Key conversion (if needed)
     - Key being added to ssh-agent

3. **Check for success:**
   - "Test SSH Connection" should succeed
   - "Test Ansible Connection" should succeed
   - "Deploy Jenkins with Ansible" should complete

## Troubleshooting

### Still Getting "error in libcrypto"?

The key might be corrupted. Try:

```bash
# Validate the key locally
ssh-keygen -y -f jenkins-key.pem
# Should output the public key

# If it fails, the key is corrupted - you need a valid key
```

### "Permission denied (publickey)"?

The private key doesn't match the public key in AWS:

1. Check your Terraform variable `key_name` matches the key pair name in AWS
2. Verify the key pair exists in AWS EC2 → Key Pairs
3. Make sure you're in the correct AWS region

### Key works locally but not in GitHub Actions?

Check the secret was pasted correctly:

1. The secret should include `-----BEGIN` and `-----END` lines
2. No extra spaces or characters
3. Use the exact output from `cat jenkins-key.pem`

## Files Changed

- `.github/workflows/terraform-deploy.yml` - Added key conversion and ssh-agent setup
- `GITHUB_SECRETS_SETUP.md` - Complete guide for setting up secrets
- `SSH_KEY_FIX.md` - This file

## Next Steps

1. Ensure your `SSH_PRIVATE_KEY` secret is set in GitHub
2. Commit the updated workflow file
3. Push to trigger a new deployment
4. Monitor the Actions tab for success

The workflow should now handle key format issues automatically!
