output "jenkins_url" {
  value = "http://${module.jenkins.public_ip}:8080"
}

output "artifact_bucket" {
  value = module.artifact_bucket.name
}