output "instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the Jenkins server"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the Jenkins server"
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "ID of the Jenkins security group"
  value       = aws_security_group.this.id
}

output "s3_bucket_name" {
  description = "Name of the Jenkins artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "s3_bucket_arn" {
  description = "ARN of the Jenkins artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "elastic_ip" {
  description = "Elastic IP address (if enabled)"
  value       = var.enable_elastic_ip ? aws_eip.jenkins[0].public_ip : null
}

output "kms_key_id" {
  description = "KMS key ID for S3 encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.s3[0].id : null
}

output "kms_key_arn" {
  description = "KMS key ARN for S3 encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.s3[0].arn : null
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.jenkins.name
}

output "security_group_name" {
  description = "Name of the Jenkins security group"
  value       = aws_security_group.this.name
}
