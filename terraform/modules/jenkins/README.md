# Jenkins Module

This module creates a complete Jenkins server infrastructure on AWS EC2 with S3 artifact storage.

## Overview

This module provisions:
- EC2 instance running Jenkins on Ubuntu 20.04 LTS
- Security group with SSH and Jenkins UI access
- S3 bucket for Jenkins artifacts storage
- Automated Jenkins installation via user data script

## Usage

```hcl
module "jenkins" {
  source = "./modules/jenkins"

  instance_type              = "t2.medium"
  ssh_cidr_blocks            = ["203.0.113.0/32"]
  artifacts_bucket_name      = "my-jenkins-artifacts-bucket"
  iam_instance_profile_name  = module.jenkins_iam.instance_profile_name
  jenkins_port               = 8080

  tags = {
    Environment = "production"
    Project     = "Jenkins"
  }
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `instance_type` | EC2 instance type for Jenkins server | `string` | Yes | - |
| `ssh_cidr_blocks` | CIDR blocks allowed to SSH into the instance | `list(string)` | Yes | - |
| `artifacts_bucket_name` | Name of the S3 bucket for Jenkins artifacts | `string` | Yes | - |
| `iam_instance_profile_name` | Name of the IAM instance profile to attach | `string` | Yes | - |
| `jenkins_port` | Port for Jenkins UI | `number` | No | `8080` |
| `tags` | Tags to apply to Jenkins resources | `map(string)` | No | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | ID of the Jenkins EC2 instance |
| `public_ip` | Public IP address of the Jenkins server |
| `private_ip` | Private IP address of the Jenkins server |
| `security_group_id` | ID of the Jenkins security group |
| `s3_bucket_name` | Name of the Jenkins artifacts S3 bucket |
| `s3_bucket_arn` | ARN of the Jenkins artifacts S3 bucket |

## Features

- **Automated Installation**: Jenkins is automatically installed via user data script
- **Security**: SSH access restricted to specified CIDR blocks
- **Artifact Storage**: Dedicated S3 bucket for Jenkins artifacts
- **Default VPC**: Uses default VPC and subnets for easy setup
- **Ubuntu 20.04 LTS**: Always uses the latest Ubuntu 20.04 AMI

## Resources Created

- `aws_instance` - Jenkins EC2 instance
- `aws_security_group` - Security group for Jenkins
- `aws_s3_bucket` - S3 bucket for artifacts

## Data Sources

- `aws_ami.ubuntu` - Latest Ubuntu 20.04 LTS AMI
- `aws_vpc.default` - Default VPC
- `aws_subnets.default` - Default subnets

## Access Jenkins

After deployment:

1. **Jenkins UI**: `http://<public_ip>:8080`
2. **SSH**: `ssh -i <key> ubuntu@<public_ip>`
3. **Initial Admin Password**: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`

## Requirements

- Terraform >= 1.2
- AWS Provider >= 4.0
- IAM instance profile with S3 permissions
- Valid SSH key pair configured in AWS

## Security Considerations

- Jenkins UI (port 8080) is open to `0.0.0.0/0` by default. Consider restricting in production.
- SSH access is restricted to `ssh_cidr_blocks` - ensure this is your actual IP.
- S3 bucket is private by default.
- IAM instance profile should have minimal required permissions.

## Notes

- Jenkins installation takes 2-3 minutes after instance launch.
- The user data script is externalized in `user-data.sh` for maintainability.
- Instance uses the first available subnet in the default VPC.
- Default instance name tag is "Terraform-Jenkins".
