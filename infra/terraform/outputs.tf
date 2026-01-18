output "jenkins_instance_id" {
  description = "The ID of the Jenkins EC2 instance"
  value       = module.web_ec2.instance_id
}

output "jenkins_public_ip" {
  description = "The public IP address of the Jenkins server"
  value       = module.web_ec2.public_ip
}
