output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.jenkins.id
}

output "key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.jenkins.arn
}

output "alias_name" {
  description = "KMS key alias name"
  value       = aws_kms_alias.jenkins.name
}

output "alias_arn" {
  description = "KMS key alias ARN"
  value       = aws_kms_alias.jenkins.arn
}
