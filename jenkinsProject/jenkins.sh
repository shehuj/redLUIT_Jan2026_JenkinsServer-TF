#!/bin/bash
set -euxo pipefail

# Log output to file (simplified for Ansible compatibility)
exec > >(tee -a /var/log/jenkins-install.log) 2>&1

echo "=========================================="
echo "Jenkins Installation Started: $(date)"
echo "=========================================="

# Update package index
apt-get update -y

# Install required utilities
apt-get install -y wget gnupg2 software-properties-common

# Install OpenJDK 17 (Jenkins prerequisite)
apt-get install -y openjdk-17-jdk
java -version

# Add Jenkins repository key and source (modern method)
wget -q -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

# Update and install Jenkins
apt-get update -y
apt-get install -y jenkins

# Enable & start Jenkins service
systemctl enable jenkins
systemctl start jenkins

# Ensure UFW is installed
apt-get install -y ufw

# Allow Jenkins through firewall and reload
ufw allow 8080
ufw --force enable
ufw reload

# Wait for Jenkins to initialize
echo "Waiting for Jenkins to start..."
sleep 45

# Verify Jenkins is running
if systemctl is-active --quiet jenkins; then
    echo "✅ Jenkins is running"
else
    echo "⚠️ Warning: Jenkins service may not be running properly"
    systemctl status jenkins --no-pager || true
fi

# Print the initial admin password to logs
echo ""
echo "=========================================="
echo "Jenkins initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword || echo "Password file not found yet"
echo "=========================================="
echo ""
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "IP unavailable")
echo "Jenkins installation completed!"
echo "Access at: http://${PUBLIC_IP}:8080"
echo ""
echo "=========================================="
echo "Jenkins Installation Completed: $(date)"
echo "=========================================="

exit 0