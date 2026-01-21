## this script installs jenkins on a ubuntu server
#!/bin/bash
set -e

# Update package index
sudo apt-get update -y

# Install required packages
sudo apt-get install -y wget gnupg2

# Install Java (Jenkins requirement)
sudo apt-get install -y openjdk-17-jdk

# Verify Java installation
java -version

# Add Jenkins repository and key (modern method)
sudo wget -q -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package index again
sudo apt-get update -y 

# Install Jenkins
sudo apt-get install -y jenkins

# Start and enable Jenkins service
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Allow Jenkins through the firewall (if ufw is enabled)
if sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow 8080
    sudo ufw reload
    echo "Firewall rule added for port 8080"
else
    echo "UFW not active - skipping firewall configuration"
fi

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 45

# Verify Jenkins is running
if sudo systemctl is-active --quiet jenkins; then
    echo "✅ Jenkins is running"
else
    echo "⚠️  Warning: Jenkins service may not be running properly"
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
