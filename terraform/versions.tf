# Terraform and Provider Version Constraints
#
# This file pins specific versions for production stability
# Update versions carefully and test in dev/staging before production

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.90"
    }
  }

  # Note: Backend configuration should be in backend.tf
  # See backend.tf.example for remote state setup
}
