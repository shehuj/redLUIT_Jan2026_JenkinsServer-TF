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
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_rsa}"

echo -e "${GREEN}=== Ansible Jenkins Deployment (Terraform already applied) ===${NC}"

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}ERROR: SSH key not found at ${SSH_KEY_PATH}${NC}"
    echo "Please set SSH_KEY_PATH environment variable or place your key at ~/.ssh/id_rsa"
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}ERROR: Ansible is not installed${NC}"
    exit 1
fi

# Get Jenkins IP from Terraform outputs
echo -e "${YELLOW}Getting Jenkins IP from Terraform outputs...${NC}"
cd "$TERRAFORM_DIR"
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
cd - > /dev/null

if [ -z "$JENKINS_IP" ]; then
    echo -e "${RED}ERROR: Could not get Jenkins IP from Terraform outputs${NC}"
    echo "Make sure Terraform has been applied successfully"
    exit 1
fi

echo -e "${GREEN}Jenkins IP: ${JENKINS_IP}${NC}"

# Update Ansible inventory
echo -e "${YELLOW}Updating Ansible inventory...${NC}"
cat > "$INVENTORY_FILE" <<EOF
[jenkins]
jenkins_server ansible_host=${JENKINS_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_KEY_PATH}

[jenkins:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo -e "${GREEN}Inventory updated${NC}"

# Test connectivity
echo -e "${YELLOW}Testing connectivity...${NC}"
cd "$ANSIBLE_DIR"
ansible jenkins -m ping

# Run playbook
echo -e "${YELLOW}Running Jenkins installation playbook...${NC}"
ansible-playbook "$PLAYBOOK" -v

cd - > /dev/null

# Get initial password
echo -e "${YELLOW}Retrieving Jenkins initial admin password...${NC}"
INITIAL_PASSWORD=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$JENKINS_IP" "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'Password file not found yet'")

# Display results
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo -e "${GREEN}Jenkins URL:${NC} http://${JENKINS_IP}:8080"
echo -e "${GREEN}SSH Access:${NC} ssh -i ${SSH_KEY_PATH} ubuntu@${JENKINS_IP}"
echo ""
echo -e "${GREEN}Initial Admin Password:${NC}"
echo "$INITIAL_PASSWORD"
