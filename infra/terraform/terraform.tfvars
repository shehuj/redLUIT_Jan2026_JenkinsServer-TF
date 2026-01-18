aws_region          = "us-east-1"
vpc_cidr            = "10.1.0.0/16"
public_subnets      = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]

# SECURITY: Restrict to your IP for production! Use 0.0.0.0/0 for testing only
# To get your IP: curl -s https://checkip.amazonaws.com
ssh_allowed_cidrs   = ["0.0.0.0/0"]  # WARNING: Open to all IPs - restrict in production!

# Ubuntu 24.04 LTS AMI for us-east-1 (x86_64)
# Find latest: aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text
ec2_ami             = "ami-0e2c8caa4b6378d8c"  # Ubuntu 24.04 LTS

ec2_instance_type   = "t3.micro"

# SSH Key Pair - Using existing AWS key pair
ssh_key_name        = "key"

common_tags = {
  Name        = "JenkinsServer"
  Environment = "dev"
  Project     = "Jenkins-CI-CD"
  ManagedBy   = "Terraform"
}