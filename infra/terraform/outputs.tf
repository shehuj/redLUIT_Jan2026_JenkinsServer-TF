output "jenkins_instance_id" {
  description = "The ID of the Jenkins EC2 instance"
  value       = module.web_ec2.instance_id
}

output "jenkins_public_ip" {
  description = "The public IP address of the Jenkins server"
  value       = module.web_ec2.public_ip
}

output "jenkins_private_ip" {
  description = "The private IP address of the Jenkins server"
  value       = module.web_ec2.private_ip
}

output "jenkins_public_dns" {
  description = "The public DNS name of the Jenkins server"
  value       = module.web_ec2.public_dns
}

output "jenkins_private_dns" {
  description = "The private DNS name of the Jenkins server"
  value       = module.web_ec2.private_dns
}

output "jenkins_availability_zone" {
  description = "The availability zone of the Jenkins server"
  value       = module.web_ec2.availability_zone
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "security_group_id" {
  description = "The ID of the Jenkins security group"
  value       = module.web_sg.sg_id
}
