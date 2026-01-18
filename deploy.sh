#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="./terraform"
ANSIBLE_DIR="./ansible"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.ini"
PLAYBOOK="${ANSIBLE_DIR}/playbooks/deploy_jenkins.yml"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_rsa}"  # Default to ~/.ssh/id_rsa, can be overridden

echo -e "${GREEN}=== Jenkins Deployment Script ===${NC}"

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}ERROR: SSH key not found at ${SSH_KEY_PATH}${NC}"
    echo "Please set SSH_KEY_PATH environment variable or place your key at ~/.ssh/id_rsa"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}ERROR: Terraform is not installed${NC}"
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}ERROR: Ansible is not installed${NC}"
    exit 1
fi

# Step 1: Run Terraform
echo -e "${YELLOW}Step 1: Provisioning infrastructure with Terraform...${NC}"
cd "$TERRAFORM_DIR"

terraform init
terraform plan -out=tfplan
echo -e "${YELLOW}Review the plan above. Press Enter to continue or Ctrl+C to cancel...${NC}"
read -r

terraform apply tfplan

# Get outputs
echo -e "${GREEN}Getting Terraform outputs...${NC}"
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
echo "Jenkins Public IP: $JENKINS_IP"

cd - > /dev/null

# Step 2: Wait for instance to be ready
echo -e "${YELLOW}Step 2: Waiting for instance to be ready...${NC}"
echo "Waiting 60 seconds for user-data script to complete..."
sleep 60

# Test SSH connectivity
echo "Testing SSH connectivity..."
MAX_RETRIES=12
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@"$JENKINS_IP" "echo 'SSH connection successful'" 2>/dev/null; then
        echo -e "${GREEN}SSH connection established!${NC}"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Retry $RETRY_COUNT/$MAX_RETRIES - waiting 10 seconds..."
        sleep 10
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}ERROR: Could not establish SSH connection after $MAX_RETRIES attempts${NC}"
    exit 1
fi

# Step 3: Update Ansible inventory
echo -e "${YELLOW}Step 3: Updating Ansible inventory...${NC}"
cat > "$INVENTORY_FILE" <<EOF
[jenkins]
jenkins_server ansible_host=${JENKINS_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_KEY_PATH}

[jenkins:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo -e "${GREEN}Inventory updated:${NC}"
cat "$INVENTORY_FILE"

# Step 4: Run Ansible playbook
echo -e "${YELLOW}Step 4: Deploying Jenkins with Ansible...${NC}"
cd "$ANSIBLE_DIR"

# Test Ansible connectivity
echo "Testing Ansible connectivity..."
ansible jenkins -m ping

# Run the playbook
echo "Running Jenkins installation playbook..."
ansible-playbook "$PLAYBOOK" -v

cd - > /dev/null

# Step 5: Get Jenkins initial password
echo -e "${YELLOW}Step 5: Retrieving Jenkins initial admin password...${NC}"
INITIAL_PASSWORD=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$JENKINS_IP" "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'Password file not found yet'")

# Display results
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo -e "${GREEN}Jenkins URL:${NC} http://${JENKINS_IP}:8080"
echo -e "${GREEN}SSH Access:${NC} ssh -i ${SSH_KEY_PATH} ubuntu@${JENKINS_IP}"
echo ""
echo -e "${GREEN}Initial Admin Password:${NC}"
echo "$INITIAL_PASSWORD"
echo ""
echo -e "${YELLOW}Note: If the password is not available yet, wait a few minutes and run:${NC}"
echo "  ssh -i ${SSH_KEY_PATH} ubuntu@${JENKINS_IP} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
