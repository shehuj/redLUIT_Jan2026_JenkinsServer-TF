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

output "jenkins_security_group_id" {
  description = "The ID of the Jenkins security group"
  value       = aws_security_group.jenkins.id
}

output "jenkins_public_dns" {
  description = "The public DNS name of the Jenkins server"
  value       = aws_instance.jenkins.public_dns
}

output "jenkins_artifacts_bucket_name" {
  description = "The name of the S3 bucket for Jenkins artifacts"
  value       = aws_s3_bucket.jenkins_artifacts.id
}

output "jenkins_artifacts_bucket_arn" {
  description = "The ARN of the S3 bucket for Jenkins artifacts"
  value       = aws_s3_bucket.jenkins_artifacts.arn
}

output "jenkins_iam_role_arn" {
  description = "The ARN of the IAM role attached to the Jenkins EC2 instance"
  value       = aws_iam_role.jenkins.arn
}

output "ssm_connection_command" {
  description = "AWS Systems Manager Session Manager connection command"
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id}"
}