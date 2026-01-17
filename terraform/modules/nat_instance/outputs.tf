output "instance_id" {
  description = "ID of the NAT instance"
  value       = aws_instance.nat.id
}

output "private_ip" {
  description = "Private IP address of the NAT instance"
  value       = aws_instance.nat.private_ip
}

output "eip" {
  description = "Elastic IP address of the NAT instance"
  value       = aws_eip.nat.public_ip
}

output "security_group_id" {
  description = "Security group ID of the NAT instance"
  value       = aws_security_group.nat.id
}
