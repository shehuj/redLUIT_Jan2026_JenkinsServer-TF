# 🔧 Quick Fix: SSH Key Error

**Error:** `Error loading key: error in libcrypto`

## Fix in 3 Minutes

### 1. Find Your Private Key

```bash
# Your key file should be named something like:
# - jenkins-key.pem
# - key.pem
# - <key_pair_name>.pem

# Common locations:
ls ~/Downloads/*.pem
ls ~/.ssh/*.pem
```

### 2. Validate the Key

```bash
# Replace with your actual key filename
ssh-keygen -y -f ~/Downloads/jenkins-key.pem
```

**If this outputs a public key → your key is valid ✅**
**If this gives an error → your key is corrupted ❌**

### 3. Copy the Key Content

```bash
# Show the key
cat ~/Downloads/jenkins-key.pem

# Or copy to clipboard (macOS):
cat ~/Downloads/jenkins-key.pem | pbcopy
```

### 4. Update GitHub Secret

1. Go to: `https://github.com/YOUR_USERNAME/redLUIT_Jan2026_JenkinsServer-TF/settings/secrets/actions`
2. Click **SSH_PRIVATE_KEY** → **Update**
3. Paste the **entire** key content (including BEGIN and END lines)
4. Click **Update secret**

### 5. Trigger New Run

```bash
cd /path/to/redLUIT_Jan2026_JenkinsServer-TF
git commit --allow-empty -m "Test SSH key fix"
git push
```

## What the Key Should Look Like

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890abcdefghijklmnopqrstuvwxyz...
AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJJJKKKKLLLLMMMM...
(many more lines of random-looking characters)
...
zzzzyyyyxxxxwwwwvvvvuuuuttttssssrrrrqqqqppppoooonnnnmm...
-----END RSA PRIVATE KEY-----
```

**Must include:**
- ✅ `-----BEGIN RSA PRIVATE KEY-----` (or BEGIN OPENSSH PRIVATE KEY)
- ✅ Multiple lines of base64-encoded data
- ✅ `-----END RSA PRIVATE KEY-----` (or END OPENSSH PRIVATE KEY)

**Must NOT include:**
- ❌ Shell prompt (`$`, `#`)
- ❌ Filename
- ❌ Extra text before BEGIN or after END
- ❌ Extra blank lines at start/end

## Still Not Working?

### Option A: Generate New Key Pair

```bash
# Generate new key
ssh-keygen -t rsa -b 4096 -m PEM -f jenkins-key-new.pem -N ""

# Import to AWS
aws ec2 import-key-pair \
  --key-name jenkins-server-key-new \
  --public-key-material fileb://jenkins-key-new.pem.pub \
  --region us-east-1

# Update GitHub Secret with jenkins-key-new.pem content
cat jenkins-key-new.pem

# Update Terraform variable
echo 'key_pair_name = "jenkins-server-key-new"' > terraform/terraform.tfvars

# Commit and push
git add terraform/terraform.tfvars
git commit -m "Update key pair name"
git push
```

### Option B: Create New Key in AWS Console

1. AWS Console → EC2 → Key Pairs → Create key pair
2. Name: `jenkins-key-2026`
3. Type: **RSA**, Format: **.pem**
4. Download the file
5. Copy content to GitHub Secret SSH_PRIVATE_KEY
6. Update `terraform/terraform.tfvars`:
   ```
   key_pair_name = "jenkins-key-2026"
   ```
7. Commit and push

## Verification

After updating the secret, the "Configure SSH Key" step should show:

```
✅ Key validation successful
```

Instead of:

```
❌ ERROR: Key validation failed!
```

## Need More Help?

See: [SSH_KEY_TROUBLESHOOTING.md](SSH_KEY_TROUBLESHOOTING.md)
