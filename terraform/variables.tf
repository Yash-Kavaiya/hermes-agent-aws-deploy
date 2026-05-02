###############################################################
# terraform/variables.tf
###############################################################

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "hermes-agent"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = <<-EOT
    EC2 instance type.
      t3.medium  (2 vCPU / 4 GB)  — good for light personal use
      t3.large   (2 vCPU / 8 GB)  — comfortable for daily use
      t3.xlarge  (4 vCPU / 16 GB) — heavy workloads
  EOT
  type        = string
  default     = "t3.medium"
}

variable "ssh_public_key" {
  description = "Your SSH public key content (e.g. contents of ~/.ssh/id_ed25519.pub)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH. Use your IP: [\"1.2.3.4/32\"]"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "github_repo" {
  description = "Your GitHub repo (user/repo-name)"
  type        = string
  default     = "Yash-Kavaiya/hermes-agent-aws-deploy"
}

# Bedrock model to use — auth is via IAM Task Role, no API key needed.
# Common options:
#   bedrock:anthropic.claude-3-5-sonnet-20241022-v2:0
#   bedrock:anthropic.claude-3-5-haiku-20241022-v1:0
#   bedrock:amazon.nova-pro-v1:0
variable "hermes_model" {
  description = "Bedrock model ID for Hermes"
  type        = string
  default     = "bedrock:anthropic.claude-3-5-sonnet-20241022-v2:0"
}

# Kept for compatibility with existing userdata.sh.tpl template
# Set to empty string — Bedrock uses IAM, not an API key
variable "openrouter_api_key" {
  description = "Unused when using Bedrock. Kept for template compatibility."
  type        = string
  sensitive   = true
  default     = ""
}
