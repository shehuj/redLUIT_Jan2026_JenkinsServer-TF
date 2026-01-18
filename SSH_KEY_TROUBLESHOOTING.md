# SSH Key Troubleshooting Guide

## Current Error

```
Error loading key "/home/runner/.ssh/key.pem": error in libcrypto
```

This error indicates the SSH private key in your GitHub Secrets is corrupted or in an incompatible format.

## Root Causes

1. **Key is corrupted** - Extra characters, missing lines, or wrong encoding
2. **Wrong format** - Key needs to be in PEM format
3. **Line ending issues** - Windows CRLF vs Unix LF
4. **Missing header/footer** - Key must include BEGIN/END lines
5. **Extra whitespace** - Leading/trailing spaces or newlines

## Solution Steps

### Step 1: Get Your Private Key File

Your private key should be the `.pem` file you downloaded from AWS when creating the key pair.

```bash
# Location examples:
# - ~/Downloads/jenkins-key.pem
# - ~/.ssh/jenkins-key.pem
# - The file you specified in terraform key_pair_name variable
```

### Step 2: Validate the Key Locally

```bash
# Test the key can be parsed
ssh-keygen -y -f ~/path/to/jenkins-key.pem

# This should output the public key
# If it fails, your key is corrupted
```

### Step 3: Check Key Format

```bash
# View the first line
head -n 1 ~/path/to/jenkins-key.pem
```

**✅ VALID FORMATS:**

**RSA Format (Preferred):**
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
...
-----END RSA PRIVATE KEY-----
```

**OpenSSH Format (Will be auto-converted):**
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAA...
...
-----END OPENSSH PRIVATE KEY-----
```

**EC Format (If using EC2 key):**
```
-----BEGIN EC PRIVATE KEY-----
...
-----END EC PRIVATE KEY-----
```

**❌ INVALID:**
- Any text before `-----BEGIN`
- Any text after `-----END-----`
- Missing BEGIN or END lines
- Corrupted base64 content

### Step 4: Convert to RSA PEM Format (if needed)

If your key is in OpenSSH format:

```bash
# Create backup
cp jenkins-key.pem jenkins-key.pem.backup

# Convert to RSA PEM format
ssh-keygen -p -f jenkins-key.pem -m pem -P "" -N ""

# Verify conversion
head -n 1 jenkins-key.pem
# Should show: -----BEGIN RSA PRIVATE KEY-----
```

### Step 5: Copy Key Content Correctly

```bash
# macOS - Copy to clipboard
cat jenkins-key.pem | pbcopy

# Linux with xclip
cat jenkins-key.pem | xclip -selection clipboard

# Linux with xsel
cat jenkins-key.pem | xsel --clipboard

# Or display and copy manually
cat jenkins-key.pem
```

**IMPORTANT:**
- Copy the **entire** output including BEGIN and END lines
- Do NOT add any extra characters
- Do NOT add extra blank lines at start or end
- Make sure no characters are cut off

### Step 6: Update GitHub Secret

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Find **SSH_PRIVATE_KEY** secret
4. Click **Update**
5. Paste the key content (entire file)
6. Click **Update secret**

### Step 7: Verify in GitHub Secret

The secret value should look like this when you paste it:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
(many more lines of base64-encoded data)
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
-----END RSA PRIVATE KEY-----
```

**Common Mistakes:**
- ❌ Only copying part of the key
- ❌ Adding description text
- ❌ Including shell prompt (like `$` or `#`)
- ❌ Including the filename
- ❌ Adding quotes around the key
- ❌ Adding extra blank lines

## Alternative: Generate New Key Pair

If your key is corrupted and you can't recover it:

### Option 1: Generate Locally and Import to AWS

```bash
# Generate new RSA key in PEM format
ssh-keygen -t rsa -b 4096 -m PEM -f jenkins-key-new.pem -N ""

# This creates:
# - jenkins-key-new.pem (private key)
# - jenkins-key-new.pem.pub (public key)

# Import public key to AWS
aws ec2 import-key-pair \
  --key-name jenkins-server-key-new \
  --public-key-material fileb://jenkins-key-new.pem.pub \
  --region us-east-1

# Update your Terraform variable
# Edit terraform/terraform.tfvars:
# key_pair_name = "jenkins-server-key-new"

# Add private key to GitHub Secrets
cat jenkins-key-new.pem
# Copy output and update SSH_PRIVATE_KEY secret
```

### Option 2: Create New Key in AWS Console

1. Go to AWS Console → EC2 → Key Pairs
2. Click **Create key pair**
3. Name: `jenkins-server-key-2026`
4. Key pair type: **RSA**
5. Private key format: **.pem**
6. Click **Create key pair**
7. Download the `.pem` file
8. Add to GitHub Secrets:
   ```bash
   cat ~/Downloads/jenkins-server-key-2026.pem
   # Copy output and add to GitHub Secrets
   ```
9. Update Terraform:
   ```hcl
   # terraform/terraform.tfvars
   key_pair_name = "jenkins-server-key-2026"
   ```

## Testing the Key

After updating the GitHub Secret:

### Test 1: Manual SSH Test (if you have an existing instance)

```bash
# Save the key locally
# (copy from GitHub secret)
cat > test-key.pem << 'EOF'
-----BEGIN RSA PRIVATE KEY-----
(paste key content here)
-----END RSA PRIVATE KEY-----
EOF

chmod 600 test-key.pem

# Test SSH connection
ssh -i test-key.pem ubuntu@<YOUR_JENKINS_IP> "echo 'Connection successful'"

# Clean up
rm test-key.pem
```

### Test 2: Trigger GitHub Actions

```bash
# Make a small change to trigger workflow
cd /path/to/redLUIT_Jan2026_JenkinsServer-TF

# Make empty commit
git commit --allow-empty -m "Test SSH key fix"
git push

# Monitor in GitHub → Actions tab
```

## Workflow Updates

The workflow now includes:

1. **Better key handling** - Uses `printf` to avoid newline issues
2. **Auto-conversion** - Converts OpenSSH to RSA format automatically
3. **Key validation** - Tests key can be read before using
4. **Verbose debugging** - Shows key format and validation results

### Debug Output to Check

When the workflow runs, check the "Configure SSH Key" step:

**✅ Success looks like:**
```
Original key format:
-----BEGIN RSA PRIVATE KEY-----
Already in RSA PEM format - no conversion needed
Validating key...
Key validation successful
```

or

```
Original key format:
-----BEGIN OPENSSH PRIVATE KEY-----
Detected OpenSSH format - converting to RSA PEM format...
Conversion complete. New format:
-----BEGIN RSA PRIVATE KEY-----
Validating key...
Key validation successful
```

**❌ Failure looks like:**
```
ERROR: Key validation failed!
Key might be corrupted or in an unsupported format
```

## Common Issues

### Issue: "No such file or directory"

**Cause:** Key name doesn't match AWS key pair name

**Fix:**
```bash
# Check AWS for key pair name
aws ec2 describe-key-pairs --region us-east-1

# Update terraform/terraform.tfvars
key_pair_name = "actual-key-name-from-aws"
```

### Issue: "Permission denied (publickey)"

**Cause:** Private key doesn't match public key in AWS

**Fix:** Make sure you're using the private key that corresponds to the public key in AWS EC2 Key Pairs

### Issue: Key works locally but not in GitHub Actions

**Cause:** Copy-paste issue or encoding problem

**Fix:**
1. Check for hidden characters: `cat -A jenkins-key.pem`
2. Ensure Unix line endings: `dos2unix jenkins-key.pem`
3. Re-copy the key to GitHub Secrets

### Issue: "Unsupported key type"

**Cause:** Using ED25519 or other unsupported key types

**Fix:** Generate RSA key as shown above

## Key Pair Naming Convention

Your Terraform configuration uses:
```hcl
variable "key_pair_name" {
  default = "key"
}
```

Make sure:
1. AWS EC2 Key Pair is named "key" (or update the variable)
2. The private key file matches this key pair
3. GitHub Secret contains the correct private key

## Final Checklist

Before pushing to GitHub:

- [ ] Private key file exists and is readable
- [ ] Can generate public key: `ssh-keygen -y -f key.pem`
- [ ] Key is in RSA PEM format (or will be auto-converted)
- [ ] Entire key including BEGIN/END copied to GitHub Secret
- [ ] No extra characters or whitespace
- [ ] Key pair name in AWS matches Terraform variable
- [ ] GitHub Secret SSH_PRIVATE_KEY is updated
- [ ] Other secrets are set (AWS_ACCESS_KEY_ID, etc.)

## Getting Help

If still having issues:

1. **Check the GitHub Actions log** - Look at "Configure SSH Key" step
2. **Verify key locally** - Test SSH connection manually
3. **Check AWS Key Pairs** - Ensure key pair exists in correct region
4. **Review Terraform variables** - Ensure key_pair_name matches AWS

## Reference

- AWS Key Pairs: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
- SSH Keygen: `man ssh-keygen`
- OpenSSH to PEM conversion: `ssh-keygen -p -m pem`
