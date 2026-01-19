#!/bin/bash
# Script to connect to Jenkins server via AWS Systems Manager Session Manager

set -e

echo "🔐 Jenkins SSM Connection Tool"
echo "======================================="
echo ""

# Check if AWS CLI is configured
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

# Check if Session Manager plugin is installed
if ! command -v session-manager-plugin &> /dev/null; then
    echo "❌ Session Manager plugin not found."
    echo ""
    echo "Install it first:"
    echo ""
    echo "macOS with Homebrew:"
    echo "  brew install --cask session-manager-plugin"
    echo ""
    echo "Or download from:"
    echo "  https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    echo ""
    exit 1
fi

# Find Jenkins instance
echo "🔍 Finding Jenkins instance..."
INSTANCE_INFO=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=jenkins-server" "Name=tag:Project,Values=JenkinsProject" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,State.Name]' \
    --output text)

if [ -z "$INSTANCE_INFO" ] || [ "$INSTANCE_INFO" == "None" ]; then
    echo "❌ No running Jenkins instance found"
    echo ""
    echo "Please check:"
    echo "1. Instance is running (not stopped)"
    echo "2. Instance has tags: Name=jenkins-server, Project=JenkinsProject"
    echo "3. AWS region is correct"
    exit 1
fi

INSTANCE_ID=$(echo "$INSTANCE_INFO" | awk '{print $1}')
PUBLIC_IP=$(echo "$INSTANCE_INFO" | awk '{print $2}')
STATE=$(echo "$INSTANCE_INFO" | awk '{print $3}')

echo "✅ Found Jenkins instance"
echo "   Instance ID: $INSTANCE_ID"
echo "   Public IP: $PUBLIC_IP"
echo "   State: $STATE"
echo ""

# Check SSM agent status
echo "🔍 Checking SSM agent status..."
SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null || echo "Unknown")

if [ "$SSM_STATUS" == "Online" ]; then
    echo "✅ SSM agent is online and ready"
elif [ "$SSM_STATUS" == "ConnectionLost" ]; then
    echo "⚠️  SSM agent connection lost - instance may be restarting"
    echo "   Wait a few moments and try again"
    exit 1
else
    echo "⚠️  SSM agent status: $SSM_STATUS"
    echo ""
    echo "If the instance was just created, wait 2-3 minutes for SSM agent to register."
    echo "The SSM agent should be pre-installed on Ubuntu AMIs."
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "======================================="
echo "🚀 Connecting to Jenkins server..."
echo "======================================="
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "Type 'exit' to disconnect when done."
echo ""
echo "======================================="
echo ""

# Start SSM session
aws ssm start-session --target "$INSTANCE_ID"
