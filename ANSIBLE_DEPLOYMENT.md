# Ansible Deployment Guide

This guide explains how to deploy Jenkins using Ansible after Terraform provisions the infrastructure.

## Prerequisites

1. **Terraform installed** - Already used to provision infrastructure
2. **Ansible installed** - Install with:
   ```bash
   # macOS
   brew install ansible

   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y ansible

   # pip
   pip3 install ansible
   ```

3. **SSH Key** - The same key you used for Terraform
   - Default location: `~/.ssh/id_rsa`
   - Custom location: Set `SSH_KEY_PATH` environment variable

4. **SSH Key Permissions** - Ensure correct permissions:
   ```bash
   chmod 600 ~/.ssh/your-key.pem
   ```

## Deployment Options

### Option 1: Full Deployment (Terraform + Ansible)

Use this for a complete fresh deployment:

```bash
# Using default SSH key (~/.ssh/id_rsa)
./deploy.sh

# Using custom SSH key
SSH_KEY_PATH=~/.ssh/jenkins-key.pem ./deploy.sh
```

This script will:
1. Run `terraform init`, `plan`, and `apply`
2. Wait for the EC2 instance to be ready
3. Test SSH connectivity
4. Update the Ansible inventory
5. Run the Ansible playbook to install Jenkins
6. Retrieve and display the initial admin password

### Option 2: Ansible Only (Terraform Already Applied)

Use this if Terraform is already applied and you just want to run Ansible:

```bash
# Using default SSH key
./ansible-deploy.sh

# Using custom SSH key
SSH_KEY_PATH=~/.ssh/jenkins-key.pem ./ansible-deploy.sh
```

This script will:
1. Get the Jenkins IP from Terraform outputs
2. Update the Ansible inventory
3. Run the Ansible playbook
4. Retrieve and display the initial admin password

### Option 3: Manual Ansible Deployment

If you prefer to run Ansible manually:

```bash
# 1. Get the Jenkins IP from Terraform
cd terraform
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
cd ..

# 2. Update the inventory file
cat > ansible/inventory/hosts.ini <<EOF
[jenkins]
jenkins_server ansible_host=${JENKINS_IP} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[jenkins:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

# 3. Test connectivity
cd ansible
ansible jenkins -m ping

# 4. Run the playbook
ansible-playbook playbooks/deploy_jenkins.yml -v

# 5. Get the initial admin password
ssh -i ~/.ssh/id_rsa ubuntu@${JENKINS_IP} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

## What Ansible Installs

The Ansible playbook (`ansible/playbooks/deploy_jenkins.yml`) installs:

1. **Java OpenJDK 17** - Required for Jenkins
2. **Jenkins** - Latest stable version from official repository
3. **Required packages** - curl, wget, gnupg, ca-certificates

### Installation Steps

The playbook performs these tasks:
1. Updates apt cache
2. Installs Java OpenJDK 17
3. Adds Jenkins GPG key
4. Adds Jenkins repository
5. Installs Jenkins
6. Enables and starts Jenkins service
7. Waits for Jenkins to be ready on port 8080
8. Retrieves the initial admin password

## Troubleshooting

### SSH Connection Issues

If you see SSH errors like "Permission denied (publickey)":

```bash
# Check key permissions
chmod 600 ~/.ssh/your-key.pem

# Test SSH manually
ssh -i ~/.ssh/your-key.pem ubuntu@<JENKINS_IP> -v
```

### Ansible Connection Issues

If Ansible can't connect:

```bash
# Test connectivity
cd ansible
ansible jenkins -m ping -vvv

# Check inventory file
cat inventory/hosts.ini
```

### Jenkins Not Starting

If Jenkins fails to start:

```bash
# SSH into the instance
ssh -i ~/.ssh/your-key.pem ubuntu@<JENKINS_IP>

# Check Jenkins status
sudo systemctl status jenkins

# Check Jenkins logs
sudo journalctl -u jenkins -n 100

# Check installation logs
sudo cat /var/log/user-data.log
```

### Password File Not Found

If the initial password isn't available:

```bash
# Wait a few minutes for Jenkins to initialize, then:
ssh -i ~/.ssh/your-key.pem ubuntu@<JENKINS_IP> 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

## Post-Deployment

After successful deployment:

1. **Access Jenkins**: http://JENKINS_IP:8080
2. **Initial Setup**:
   - Use the initial admin password displayed by the script
   - Install suggested plugins
   - Create your admin user
   - Configure Jenkins URL

3. **Security**:
   - Change admin password immediately
   - Configure authentication (LDAP, SAML, etc.)
   - Set up project-based authorization
   - Enable CSRF protection

4. **Configuration**:
   - Install additional plugins as needed
   - Configure build agents
   - Set up credentials
   - Create your first pipeline

## Files Created

The deployment creates/updates these files:

```
ansible/
├── inventory/
│   └── hosts.ini              # Dynamic inventory (auto-generated)
├── playbooks/
│   └── deploy_jenkins.yml     # Main playbook
├── roles/
│   └── jenkins/
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── install.yml
│       │   └── retrieve_password.yml
│       ├── handlers/
│       │   └── main.yml
│       └── defaults/
│           └── main.yml
└── ansible.cfg                # Ansible configuration
```

## Next Steps

- Configure Jenkins pipelines
- Set up GitHub/GitLab integration
- Configure build agents
- Set up artifact storage (S3)
- Configure backup strategies

For cleanup instructions, see [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md)
