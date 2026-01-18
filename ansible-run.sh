#!/bin/bash

# Dynamic Ansible Runner - Fetches Terraform outputs at runtime
# Usage: ./ansible-run.sh [ansible-command-args]
# Examples:
#   ./ansible-run.sh -m ping
#   ./ansible-run.sh -m shell -a "uptime"
#   Or use with playbook: ./ansible-run.sh --playbook ansible/playbooks/deploy_jenkins.yml

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="infra/terraform"
INVENTORY_DIR="ansible/inventory"
INVENTORY_FILE="${INVENTORY_DIR}/hosts.ini"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/jenkins-key.pem}"  # Can be overridden via env var

echo -e "${GREEN}🚀 Dynamic Ansible Runner${NC}"
echo "================================"

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Terraform directory not found at $TERRAFORM_DIR${NC}"
    exit 1
fi

# Get Jenkins public IP from Terraform output
echo -e "${YELLOW}📡 Fetching Jenkins IP from Terraform...${NC}"
cd "$TERRAFORM_DIR"

# Check if terraform state exists
if ! terraform show &>/dev/null; then
    echo -e "${RED}Error: No Terraform state found. Please run 'terraform apply' first.${NC}"
    exit 1
fi

# Get the public IP
JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null)

if [ -z "$JENKINS_IP" ] || [ "$JENKINS_IP" = "null" ]; then
    echo -e "${RED}Error: Could not retrieve Jenkins public IP from Terraform outputs${NC}"
    echo "Make sure Terraform has been applied and the jenkins_public_ip output exists"
    exit 1
fi

echo -e "${GREEN}✓ Jenkins IP: $JENKINS_IP${NC}"

# Go back to project root
cd - > /dev/null

# Create inventory directory if it doesn't exist
mkdir -p "$INVENTORY_DIR"

# Generate dynamic inventory
echo -e "${YELLOW}📝 Generating dynamic inventory...${NC}"
cat > "$INVENTORY_FILE" << EOF
[jenkins]
jenkins_server ansible_host=${JENKINS_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_KEY_PATH}

[jenkins:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo -e "${GREEN}✓ Inventory generated at $INVENTORY_FILE${NC}"

# Check if running a playbook or ad-hoc command
if [[ "$*" == *"--playbook"* ]]; then
    # Extract playbook path
    PLAYBOOK_PATH=$(echo "$@" | sed -n 's/.*--playbook \([^ ]*\).*/\1/p')
    EXTRA_ARGS=$(echo "$@" | sed 's/--playbook [^ ]*//')

    echo -e "${YELLOW}🎭 Running Ansible playbook: $PLAYBOOK_PATH${NC}"
    echo "================================"

    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_PATH" $EXTRA_ARGS
else
    # Run ad-hoc command
    echo -e "${YELLOW}⚡ Running Ansible ad-hoc command${NC}"
    echo "================================"

    ansible -i "$INVENTORY_FILE" jenkins "$@"
fi

echo -e "${GREEN}✓ Complete!${NC}"
