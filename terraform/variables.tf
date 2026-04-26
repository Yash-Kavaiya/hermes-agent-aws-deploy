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
    Recommendations:
      t3.medium  (2 vCPU / 4 GB)  — good for light personal use, ~$0.04/hr
      t3.large   (2 vCPU / 8 GB)  — comfortable for daily use, ~$0.08/hr
      t3.xlarge  (4 vCPU / 16 GB) — heavy workloads / Docker backends, ~$0.17/hr
      g4dn.xlarge                  — if you want a local GPU model, ~$0.53/hr
  EOT
  type        = string
  default     = "t3.medium"
}

variable "ssh_public_key" {
  description = "Your SSH public key content (e.g. contents of ~/.ssh/id_ed25519.pub)"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH. Use your home IP: [\"1.2.3.4/32\"]"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ⚠ Lock this down in production!
}

variable "github_repo" {
  description = "Your GitHub repo (user/repo-name)"
  type        = string
  default     = "your-username/hermes-ec2"
}

variable "openrouter_api_key" {
  description = "OpenRouter API key for Hermes (or any other provider key)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "hermes_model" {
  description = "Model string for Hermes (e.g. openrouter:anthropic/claude-sonnet-4-5)"
  type        = string
  default     = "openrouter:anthropic/claude-sonnet-4-5"
}
