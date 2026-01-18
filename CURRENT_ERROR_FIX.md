# Current Error - Fix Now

## The Error You're Seeing

```
Error loading key "/home/runner/.ssh/key.pem": error in libcrypto
Error: Process completed with exit code 1.
```

## What This Means

Your **SSH_PRIVATE_KEY** in GitHub Secrets is corrupted, improperly formatted, or wasn't copied correctly.

## Fix It in 5 Minutes

### Step 1: Locate Your Private Key File

This is the `.pem` file you downloaded from AWS when you created your EC2 key pair.

**Check these locations:**
```bash
ls ~/Downloads/*.pem
ls ~/.ssh/*.pem
```

**Don't have it?** → See "Option B: Create New Key" below

### Step 2: Verify the Key Works

```bash
# Test the key (replace 'key.pem' with your actual filename)
ssh-keygen -y -f ~/Downloads/key.pem
```

**Expected output:** A long string starting with `ssh-rsa` or `ecdsa-sha2`

**If you get an error:** Your key file is corrupted - use Option B to create a new one

### Step 3: View and Copy the Key

```bash
# Display the key
cat ~/Downloads/key.pem
```

**Copy the ENTIRE output** - it should look like this:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(many lines)
...
-----END RSA PRIVATE KEY-----
```

**macOS shortcut to copy:**
```bash
cat ~/Downloads/key.pem | pbcopy
```

### Step 4: Update GitHub Secret

1. **Go to your repository settings:**
   ```
   https://github.com/YOUR_USERNAME/redLUIT_Jan2026_JenkinsServer-TF/settings/secrets/actions
   ```

2. **Find SSH_PRIVATE_KEY**
   - Click the **Update** button

3. **Paste the key**
   - Paste the ENTIRE content you copied
   - Make sure it includes `-----BEGIN` and `-----END` lines
   - No extra spaces or text

4. **Click "Update secret"**

### Step 5: Verify the Secret

The secret should contain:
- ✅ BEGIN line
- ✅ Multiple lines of encoded data
- ✅ END line
- ❌ NO extra text, quotes, or whitespace

### Step 6: Test the Fix

```bash
cd /path/to/redLUIT_Jan2026_JenkinsServer-TF

# Make an empty commit to trigger the workflow
git commit --allow-empty -m "Fix SSH key in GitHub Secrets"
git push origin main
```

### Step 7: Monitor the Workflow

1. Go to **GitHub → Actions** tab
2. Watch the latest workflow run
3. Check the **"Configure SSH Key"** step
4. Should see: `✅ Key validation successful`

---

## Option B: Create New Key (If You Don't Have the Original)

### If Using AWS Console

1. **AWS Console → EC2 → Key Pairs**
2. **Click "Create key pair"**
   - Name: `jenkins-key-2026`
   - Type: **RSA**
   - Format: **.pem**
3. **Click "Create"** - file downloads automatically
4. **Copy the content:**
   ```bash
   cat ~/Downloads/jenkins-key-2026.pem
   ```
5. **Add to GitHub Secret** (SSH_PRIVATE_KEY)
6. **Update Terraform variable:**
   ```bash
   cd terraform
   echo 'key_pair_name = "jenkins-key-2026"' > terraform.tfvars
   git add terraform.tfvars
   git commit -m "Update SSH key pair name"
   git push
   ```

### If Using AWS CLI

```bash
# Generate new key locally
ssh-keygen -t rsa -b 4096 -m PEM -f jenkins-key-2026.pem -N ""

# Import to AWS
aws ec2 import-key-pair \
  --key-name jenkins-key-2026 \
  --public-key-material fileb://jenkins-key-2026.pem.pub \
  --region us-east-1

# Copy private key content
cat jenkins-key-2026.pem

# Add to GitHub Secret (SSH_PRIVATE_KEY)

# Update Terraform
cd terraform
echo 'key_pair_name = "jenkins-key-2026"' > terraform.tfvars
git add terraform.tfvars
git commit -m "Update SSH key pair name"
git push
```

---

## What Changed in the Workflow

The updated workflow now:

1. **Validates the key** before using it
2. **Auto-converts** OpenSSH format to RSA format
3. **Shows detailed errors** if key is invalid
4. **Tests SSH connection** before running Ansible

Check the "Configure SSH Key" step in your GitHub Actions log for detailed output.

---

## Expected Workflow Output

### ✅ SUCCESS - Should see:

```
Original key format:
-----BEGIN RSA PRIVATE KEY-----
Already in RSA PEM format - no conversion needed
Validating key...
Key validation successful
```

### ❌ FAILURE - Currently seeing:

```
Error loading key "/home/runner/.ssh/key.pem": error in libcrypto
```

---

## After Fixing

Once the SSH key is fixed, the workflow should:

1. ✅ Configure SSH Key
2. ✅ Test SSH Connection
3. ✅ Wait for EC2 Initialization
4. ✅ Create Ansible Inventory
5. ✅ Test Ansible Connection
6. ✅ Deploy Jenkins with Ansible
7. ✅ Get Jenkins Initial Password

You'll then have a working Jenkins server!

---

## Quick Checklist

- [ ] Found my private key file (`.pem`)
- [ ] Verified it works: `ssh-keygen -y -f key.pem`
- [ ] Copied entire key content including BEGIN/END
- [ ] Updated GitHub Secret SSH_PRIVATE_KEY
- [ ] No extra text, spaces, or characters added
- [ ] Pushed empty commit to trigger workflow
- [ ] Workflow shows "Key validation successful"

---

## Still Stuck?

1. **Check key format:** `head -1 ~/Downloads/key.pem` should show `-----BEGIN`
2. **Check for hidden characters:** `cat -A ~/Downloads/key.pem`
3. **Try creating new key:** Use Option B above
4. **Check AWS key pair name:** Must match `key_pair_name` in Terraform

**Detailed help:** See [SSH_KEY_TROUBLESHOOTING.md](SSH_KEY_TROUBLESHOOTING.md)

---

**This is the only blocking issue right now. Fix the SSH key and the deployment will work!**
