# IAM Instance Profile Module

This module creates an IAM instance profile with an associated role and S3 access policy for EC2 instances.

## Overview

This is a reusable module that provisions:
- IAM role with EC2 assume role policy
- IAM policy for S3 bucket access
- IAM role policy attachment
- IAM instance profile (required for EC2 instance attachment)

## Usage

```hcl
module "jenkins_iam" {
  source = "./modules/iam-instance-profile"

  role_name              = "jenkins-ec2-role"
  instance_profile_name  = "jenkins-instance-profile"
  policy_name            = "jenkins-s3-rw-policy"
  s3_bucket_arn          = aws_s3_bucket.jenkins_artifacts.arn

  tags = {
    Environment = "production"
    Project     = "Jenkins"
  }
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `role_name` | Name of the IAM role | `string` | Yes | - |
| `instance_profile_name` | Name of the IAM instance profile | `string` | Yes | - |
| `policy_name` | Name of the IAM policy | `string` | Yes | - |
| `s3_bucket_arn` | ARN of the S3 bucket for policy permissions | `string` | Yes | - |
| `tags` | Tags to apply to IAM resources | `map(string)` | No | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | ARN of the IAM role |
| `role_name` | Name of the IAM role |
| `instance_profile_name` | Name of the IAM instance profile (use this for EC2) |
| `instance_profile_arn` | ARN of the IAM instance profile |
| `policy_arn` | ARN of the IAM policy |

## Features

- **S3 Full Access**: Grants full S3 permissions to the specified bucket and its objects
- **EC2 Assume Role**: Allows EC2 instances to assume the role
- **Tagging Support**: Apply consistent tags across all IAM resources
- **Instance Profile**: Includes the often-forgotten instance profile resource

## Resources Created

- `aws_iam_role` - IAM role for EC2 instances
- `aws_iam_policy` - Policy granting S3 access
- `aws_iam_role_policy_attachment` - Attaches policy to role
- `aws_iam_instance_profile` - Profile for attaching role to EC2 instances

## Requirements

- Terraform >= 1.2
- AWS Provider >= 4.0

## Notes

- The S3 policy grants `s3:*` permissions. Consider restricting to specific actions in production.
- The instance profile name is what you'll reference in EC2 `iam_instance_profile` attribute.
- All resources share the same tags for consistent labeling.
