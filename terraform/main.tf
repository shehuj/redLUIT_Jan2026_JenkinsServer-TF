module "vpc" {
  source         = "./modules/vpc"
  name           = "jenkins-vpc"
  cidr_block     = "10.0.0.0/16"
  public_subnets = ["10.0.1.0/24"]
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
  source      = "./modules/iam_role"
  role_name   = "jenkins-s3-role"
  s3_resources = [
    module.artifact_bucket.name,
    "${module.artifact_bucket.name}/*"
  ]
}

module "jenkins" {
  source           = "./modules/ec2_jenkins"
  subnet_id        = module.vpc.public_subnets_ids[0]
  instance_type    = "t2.micro"
  key_name         = var.key_pair_name
  security_groups  = [module.sg.id]
  instance_profile = module.iam.instance_profile
}