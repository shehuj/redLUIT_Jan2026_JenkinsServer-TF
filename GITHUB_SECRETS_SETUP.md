# GitHub Secrets Setup Guide

This guide explains how to properly configure GitHub Secrets for the Terraform and Ansible deployment workflow.

## Required Secrets

Navigate to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

### 1. AWS Credentials

**AWS_ACCESS_KEY_ID**
- Your AWS access key ID
- Example: `AKIAIOSFODNN7EXAMPLE`

**AWS_SECRET_ACCESS_KEY**
- Your AWS secret access key
- Example: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

**AWS_REGION**
- AWS region for deployment
- Example: `us-east-1` or `ap-southeast-1`

### 2. SSH Private Key

**SSH_PRIVATE_KEY** - This is the most critical secret and must be formatted correctly.

#### Correct Format

The SSH private key should be in **RSA format** (not OpenSSH new format). The workflow will auto-convert if needed, but it's better to use the correct format from the start.

#### How to Get Your SSH Private Key

1. **If you have the key in your AWS EC2 Key Pairs:**
   ```bash
   # Your key should be named something like jenkins-key.pem
   cat ~/Downloads/jenkins-key.pem
   ```

2. **Verify the key format:**

   **✅ CORRECT - RSA Format (preferred):**
   ```
   -----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEA...
   ...
   -----END RSA PRIVATE KEY-----
   ```

   **⚠️ ACCEPTABLE - OpenSSH Format (will be converted):**
   ```
   -----BEGIN OPENSSH PRIVATE KEY-----
   b3BlbnNzaC1rZXktdjEAAAAABG5vbmUA...
   ...
   -----END OPENSSH PRIVATE KEY-----
   ```

3. **Convert OpenSSH format to RSA format if needed:**
   ```bash
   # Create a copy first
   cp jenkins-key.pem jenkins-key-rsa.pem

   # Convert to RSA format
   ssh-keygen -p -N "" -m pem -f jenkins-key-rsa.pem

   # Verify the conversion
   head -n 1 jenkins-key-rsa.pem
   # Should show: -----BEGIN RSA PRIVATE KEY-----
   ```

#### Adding the Secret to GitHub

1. Copy the **entire** private key file content:
   ```bash
   # macOS
   cat jenkins-key.pem | pbcopy

   # Linux
   cat jenkins-key.pem | xclip -selection clipboard

   # Or just display and copy manually
   cat jenkins-key.pem
   ```

2. Go to GitHub repository → Settings → Secrets and variables → Actions

3. Click "New repository secret"

4. Name: `SSH_PRIVATE_KEY`

5. Value: Paste the **entire** key including header and footer:
   ```
   -----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ... (many more lines) ...
   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   -----END RSA PRIVATE KEY-----
   ```

6. Click "Add secret"

## Common Issues and Solutions

### Issue 1: "Load key: error in libcrypto"

**Cause:** The SSH key is in an incompatible format or corrupted.

**Solution:**
1. Verify the key format (see above)
2. Convert to RSA format if needed
3. Ensure the entire key (including headers) is copied
4. Check for no extra whitespace or characters

### Issue 2: "Permission denied (publickey)"

**Cause:** The private key doesn't match the public key configured in AWS.

**Solution:**
1. Verify you're using the same key pair name in Terraform (`key_name` variable)
2. Ensure the key pair exists in AWS EC2 → Key Pairs in the target region
3. Make sure the private key matches the public key in AWS

### Issue 3: Key has incorrect line endings

**Cause:** Copying the key on Windows might add CRLF line endings.

**Solution:**
```bash
# Convert line endings
dos2unix jenkins-key.pem

# Or manually
sed -i 's/\r$//' jenkins-key.pem
```

## Testing Your Secrets Locally

Before pushing to GitHub, test the key locally:

```bash
# Set the key
export SSH_KEY="$(cat jenkins-key.pem)"

# Save it to a file
mkdir -p ~/.ssh
echo "$SSH_KEY" > ~/.ssh/test-key.pem
chmod 600 ~/.ssh/test-key.pem

# Test SSH connection (replace IP with your Jenkins server)
ssh -i ~/.ssh/test-key.pem ubuntu@<JENKINS_IP> "echo 'Connection successful'"

# Clean up
rm ~/.ssh/test-key.pem
```

## Terraform Variables in Secrets

If you need to override Terraform variables, you can add them as secrets:

**TF_VAR_instance_type**
- Example: `t3.medium`

**TF_VAR_allowed_cidr_blocks**
- Example: `["0.0.0.0/0"]` (JSON format)

These will be automatically picked up by Terraform as environment variables.

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Rotate credentials regularly** - especially AWS access keys
3. **Use least privilege** - IAM user should only have required permissions:
   - EC2 (create, describe, terminate)
   - VPC (create, describe, delete)
   - S3 (create, delete, put, get)
   - IAM (create/delete roles, policies)
   - KMS (create, describe keys)
4. **Enable MFA** for your AWS account
5. **Use separate AWS accounts** for different environments
6. **Delete old key pairs** from AWS when no longer needed

## Verifying Secrets are Set Correctly

After adding all secrets, they should appear in:
- Repository → Settings → Secrets and variables → Actions → Repository secrets

You should see:
- ✅ AWS_ACCESS_KEY_ID
- ✅ AWS_SECRET_ACCESS_KEY
- ✅ AWS_REGION
- ✅ SSH_PRIVATE_KEY

The workflow will fail early if any secrets are missing.

## Next Steps

After setting up secrets:
1. Push changes to trigger the workflow
2. Monitor the workflow in Actions tab
3. Check the deployment summary for Jenkins URL and password
4. Access Jenkins and complete initial setup

For deployment details, see [ANSIBLE_DEPLOYMENT.md](ANSIBLE_DEPLOYMENT.md)
