terraform {
  backend "s3" {
    # Note: Backend configuration doesn't support interpolation
    # The actual key is set via -backend-config during terraform init in CI/CD
    # For local use: terraform init -backend-config="key=terraform-states/dev/infra.tfstate"

    bucket         = "ec2-shutdown-lambda-bucket"
    key            = "jenkins-states/default/infra.tfstate" # Overridden by -backend-config
    region         = "us-east-1"
    dynamodb_table = "dyning_table"
    encrypt        = true
  }
}