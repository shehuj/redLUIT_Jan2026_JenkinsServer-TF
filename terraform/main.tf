# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
  # Exclude local zones and wavelength zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source         = "./modules/vpc"
  name           = "jenkins-vpc"
  cidr_block     = "10.0.0.0/16"
  public_subnets = ["10.0.1.0/24", "10.0.3.0/24"]
  # Use first two available AZs (typically us-east-1a and us-east-1b)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "sg" {
  source      = "./modules/security_group"
  vpc_id      = module.vpc.vpc_id
  name        = "jenkins-sg"
  description = "SSH and Jenkins"
  ingress = [
    { from = 22, to = 22, protocol = "tcp", cidr = [var.allowed_ssh_cidr] },
    { from = 8080, to = 8080, protocol = "tcp", cidr = ["0.0.0.0/0"] }
  ]
}

module "artifact_bucket" {
  source      = "./modules/s3_bucket"
  bucket_name = var.artifact_bucket_name
}

module "iam" {
  source    = "./modules/iam_role"
  role_name = "jenkins-s3-role"
  s3_resources = [
    module.artifact_bucket.arn,
    "${module.artifact_bucket.arn}/*"
  ]
}

module "jenkins" {
  source           = "./modules/ec2_jenkins"
  subnet_id        = module.vpc.public_subnet_ids[0]
  instance_type    = var.instance_type
  key_name         = var.key_pair_name
  security_groups  = [module.sg.id]
  instance_profile = module.iam.instance_profile
}