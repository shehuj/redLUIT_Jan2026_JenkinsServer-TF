terraform {
  backend "s3" {
    bucket         = "ec2-shutdown-lambda-bucket"
    key            = "terraform-states/${terraform.workspace}/infra.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dyning_table"
    encrypt        = true
  }
}