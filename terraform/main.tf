# IAM Instance Profile Module
# Creates IAM role, policy, and instance profile for Jenkins EC2 instance
module "jenkins_iam" {
  source = "./modules/iam-instance-profile"

  role_name             = "jenkins-ec2-role"
  instance_profile_name = "jenkins-instance-profile"
  policy_name           = "jenkins-s3-rw-policy"
  s3_bucket_arn         = module.jenkins.s3_bucket_arn

  tags = merge(
    var.tags,
    {
      Environment = var.environment
    }
  )
}

# Jenkins Server Module
# Creates EC2 instance, security group, and S3 bucket for Jenkins
module "jenkins" {
  source = "./modules/jenkins"

  instance_type             = var.jenkins_instance_type
  ssh_cidr_blocks           = [var.public_ip]
  artifacts_bucket_name     = var.jenkins_s3_bucket_name
  iam_instance_profile_name = module.jenkins_iam.instance_profile_name
  jenkins_port              = var.jenkins_port

  tags = merge(
    var.tags,
    {
      Environment = var.environment
    }
  )
}