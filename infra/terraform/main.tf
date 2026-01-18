module "vpc" {
  source         = "./modules/vpc"
  vpc_cidr       = var.vpc_cidr
  public_subnets = var.public_subnets
  tags           = var.common_tags
}

module "web_sg" {
  source    = "./modules/security_group"
  vpc_id    = module.vpc.vpc_id
  name      = "${var.common_tags.Name}-web-sg"
  tags      = var.common_tags
  ssh_cidrs = var.ssh_allowed_cidrs
}

module "web_ec2" {
  source             = "./modules/ec2"
  ami                = var.ec2_ami
  instance_type      = var.ec2_instance_type
  subnet_id          = element(module.vpc.public_subnet_ids, 0)
  security_group_ids = [module.web_sg.sg_id]
  key_name           = var.ssh_key_name
  tags               = var.common_tags
}