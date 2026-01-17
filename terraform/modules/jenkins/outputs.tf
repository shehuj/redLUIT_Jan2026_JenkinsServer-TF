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
