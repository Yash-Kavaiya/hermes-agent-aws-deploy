###############################################################
# Terraform Remote State — S3 + DynamoDB lock
# Run `scripts/bootstrap-backend.sh` once before terraform init
###############################################################
terraform {
  backend "s3" {
    # Replace with your actual S3 bucket created by bootstrap script
    bucket         = "hermes-terraform-state-REPLACE_WITH_ACCOUNT_ID"
    key            = "hermes-agent/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "hermes-terraform-locks"
  }
}
# NOTE: required_providers and provider "aws" blocks live in main.tf
# to avoid duplicate configuration errors.
