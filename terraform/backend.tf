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

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.7.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "hermes-agent"
      Repository  = "Yash-Kavaiya/hermes-agent-aws-deploy"
      ManagedBy   = "terraform"
    }
  }
}
