output "public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.jenkins.public_ip
}

output "private_ip" {
  description = "Private IP of EC2"
  value       = aws_instance.jenkins.private_ip
}