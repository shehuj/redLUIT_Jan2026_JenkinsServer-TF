#!/bin/bash
set -e

echo "=== Starting Jenkins installation ==="

# Update package index
sudo apt-get update -y

# Install required packages
sudo apt-get install -y wget gnupg2 curl

# Install Java (Jenkins requirement)
# Using OpenJDK 21 as recommended by current docs
sudo apt-get install -y fontconfig openjdk-21-jre

# Verify Java installation
java -version

# Add the Jenkins repository signing key (new 2026 key)
echo "Adding Jenkins repository GPG key..."
sudo mkdir -p /usr/share/keyrings
sudo curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins repository
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/" \
    | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package index with Jenkins repo
sudo apt-get update -y

# Install Jenkins
sudo apt-get install -y jenkins

# Start and enable Jenkins service
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Firewall (optional)
if sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow 8080
    sudo ufw reload
    echo "✅ Firewall rule added for port 8080"
else
    echo "⚠️ UFW not active — skipping firewall configuration"
fi

# Wait for Jenkins to start
echo "Waiting for Jenkins to initialize..."
sleep 30

# Verify Jenkins service status
if sudo systemctl is-active --quiet jenkins; then
    echo "✅ Jenkins service is running"
else
    echo "❌ Jenkins service may not be running properly"
    sudo systemctl status jenkins --no-pager
fi

# Print initial admin password
echo ""
echo "=========================================="
echo "Jenkins initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "=========================================="
echo ""
echo "Jenkins installation completed!"
echo "Access it at http://your_server_ip_or_domain:8080"
echo "=========================================="