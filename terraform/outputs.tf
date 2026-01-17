# Backwards compatible outputs (existing output names preserved)
output "jenkins_public_ip" {
  description = "Public IP of Jenkins server"
  value       = module.jenkins.public_ip
}

output "artifacts_bucket" {
  description = "S3 bucket for Jenkins artifacts"
  value       = module.jenkins.s3_bucket_name
}

# Additional outputs
output "jenkins_instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = module.jenkins.instance_id
}

output "jenkins_sg_id" {
  description = "Security group ID for Jenkins"
  value       = module.jenkins.security_group_id
}

output "jenkins_iam_role_arn" {
  description = "ARN of the Jenkins IAM role"
  value       = module.jenkins_iam.role_arn
}