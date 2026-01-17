output "jenkins_url" {
  description = "Jenkins server URL"
  value       = "http://${module.jenkins.public_ip}:8080"
}

output "jenkins_public_ip" {
  description = "Public IP for SSH and Ansible access"
  value       = module.jenkins.public_ip
}

output "artifact_bucket" {
  description = "S3 bucket for Jenkins artifacts"
  value       = module.artifact_bucket.name
}