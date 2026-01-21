#!/bin/bash
set -eux

echo "=========================================="
echo "Jenkins Installation Started: $(date)"
echo "=========================================="

# Update package index
apt-get update -y

# Install required utilities
apt-get install -y curl wget gnupg2 software-properties-common

# Install OpenJDK 17 (Jenkins prerequisite)
apt-get install -y openjdk-17-jdk
java -version

# Add Jenkins repository key using the official method
# Download and import the Jenkins GPG key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Verify the key was imported
gpg --no-default-keyring --keyring /usr/share/keyrings/jenkins-keyring.asc --list-keys

# Add Jenkins repository with the keyring
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list and install Jenkins
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
sleep 30

# Verify Jenkins is running
if systemctl is-active --quiet jenkins; then
    echo "✅ Jenkins is running"
else
    echo "⚠️ Warning: Jenkins service may not be running properly"
    systemctl status jenkins --no-pager || true
fi

# Wait for Jenkins to fully initialize and create the password file
echo "Waiting for Jenkins to complete initialization..."
MAX_WAIT=120
COUNTER=0
while [ ! -f /var/lib/jenkins/secrets/initialAdminPassword ] && [ $COUNTER -lt $MAX_WAIT ]; do
    sleep 5
    COUNTER=$((COUNTER + 5))
    echo "Waiting for password file... ($COUNTER seconds)"
done

# Print the initial admin password to logs
echo ""
echo "=========================================="
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Jenkins initial admin password:"
    cat /var/lib/jenkins/secrets/initialAdminPassword
else
    echo "⚠️ Password file not created yet. Jenkins may still be initializing."
    echo "You can retrieve it later with: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi
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