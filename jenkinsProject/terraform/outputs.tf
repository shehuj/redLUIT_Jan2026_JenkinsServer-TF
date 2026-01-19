output "jenkins_public_ip" {
  description = "The public IP address of the Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_private_ip" {
  description = "The private IP address of the Jenkins server"
  value       = aws_instance.jenkins.private_ip
}

output "jenkins_instance_id" {
  description = "The ID of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.id
}