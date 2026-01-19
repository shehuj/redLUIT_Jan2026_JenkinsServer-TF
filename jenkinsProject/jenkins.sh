#!/bin/bash
set -euxo pipefail

# Log to both cloud-init-output.log and console (optional)
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update package index
apt-get update -y

# Install required utilities
apt-get install -y wget gnupg2 software-properties-common

# Install OpenJDK 11 (Jenkins prerequisite)
apt-get install -y openjdk-11-jdk
java -version

# Add Jenkins repository key and source
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
sh -c 'echo "deb http://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list'

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
sleep 30

# Print the initial admin password to logs
echo "Jenkins initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword || true
echo "Jenkins installation completed. Access at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"