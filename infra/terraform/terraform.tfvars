aws_region          = "us-east-1"
vpc_cidr            = "10.1.0.0/16"
public_subnets      = ["10.1.1.0/24","10.1.2.0/24","10.1.3.0/24"]
ssh_allowed_cidrs   = ["203.0.113.0/24"] # lock SSH access to your IP
ec2_ami             = "ami-0abcdef1234567890"
ec2_instance_type   = "t3.micro"

common_tags = {
  Name        = "myapp"
  Environment = "prod"
}