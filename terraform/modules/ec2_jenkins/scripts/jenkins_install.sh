#!/bin/bash
set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Logging setup
exec > >(tee -a /var/log/jenkins-install.log)
exec 2>&1
echo "=== Jenkins Installation Script Started at $(date) ==="

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Wait for cloud-init to complete
echo "Waiting for cloud-init to complete..."
cloud-init status --wait || true

# Wait for apt locks to be released
echo "Waiting for apt locks to be released..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "Waiting for other apt processes to finish..."
    sleep 5
done

# Update package lists
echo "Updating package lists..."
apt-get update -y

# Install Java OpenJDK 17 (required for Jenkins)
echo "Installing Java OpenJDK 17..."
apt-get install -y openjdk-17-jdk

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    gnupg \
    ca-certificates \
    curl \
    wget

# Add Jenkins GPG key
echo "Adding Jenkins GPG key..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins repository
echo "Adding Jenkins repository..."
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package lists after adding Jenkins repo
echo "Updating package lists after adding Jenkins repo..."
apt-get update -y

# Install Jenkins
echo "Installing Jenkins..."
apt-get install -y jenkins

# Enable and start Jenkins service
echo "Enabling and starting Jenkins service..."
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start on port 8080..."
timeout=300
elapsed=0
while ! netstat -tuln | grep -q ':8080 '; do
    if [ $elapsed -ge $timeout ]; then
        echo "ERROR: Jenkins failed to start within ${timeout} seconds"
        exit 1
    fi
    echo "Waiting for Jenkins to start... ($elapsed/$timeout seconds)"
    sleep 10
    elapsed=$((elapsed + 10))
done

# Check Jenkins service status
echo "Jenkins service status:"
systemctl status jenkins --no-pager

# Display initial admin password location
echo "Jenkins has been installed successfully!"
echo "Initial admin password can be found at: /var/lib/jenkins/secrets/initialAdminPassword"
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Initial Admin Password:"
    cat /var/lib/jenkins/secrets/initialAdminPassword
fi

# Create marker file
echo "Jenkins installation completed at $(date)" > /var/log/jenkins-install-complete
echo "=== Jenkins Installation Script Completed Successfully at $(date) ==="
