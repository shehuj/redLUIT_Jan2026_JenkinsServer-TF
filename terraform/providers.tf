# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  # Note: Tags are managed centrally via locals.all_tags and applied to each resource
  # This approach provides better control and consistency than default_tags
  # See locals.tf for tag definitions
}