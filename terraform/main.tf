###############################################################
# Hermes Agent — AWS EC2 Deployment
# terraform/main.tf
###############################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ─── Remote State (optional but recommended) ───────────────
  # Uncomment after creating your S3 bucket + DynamoDB table.
  # backend "s3" {
  #   bucket         = "YOUR-BUCKET-NAME-terraform-state"
  #   key            = "hermes-agent/terraform.tfstate"
  #   region         = var.aws_region
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

###############################################################
# Data — latest Ubuntu 24.04 LTS AMI
###############################################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################
# VPC — use the default VPC for simplicity
###############################################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

###############################################################
# Key Pair — import your public key
###############################################################
resource "aws_key_pair" "hermes" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

###############################################################
# Security Group
###############################################################
resource "aws_security_group" "hermes" {
  name        = "${var.project_name}-sg"
  description = "Hermes Agent security group"
  vpc_id      = data.aws_vpc.default.id

  # SSH — restrict to your IP in production!
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # HTTP — Nginx → Hermes web gateway
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Hermes gateway port (direct access, optional)
  ingress {
    description = "Hermes gateway"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

###############################################################
# IAM Role — lets EC2 use SSM (no SSH keys needed in CI/CD)
###############################################################
resource "aws_iam_role" "hermes_ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.hermes_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "hermes" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.hermes_ec2.name
}

###############################################################
# EC2 Instance
###############################################################
resource "aws_instance" "hermes" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.hermes.key_name
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.hermes.id]
  iam_instance_profile   = aws_iam_instance_profile.hermes.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30   # GB — enough for Hermes + Docker images
    delete_on_termination = true
    encrypted             = true
  }

  # Cloud-init bootstrap — installs Docker, pulls repo, starts Hermes
  user_data = templatefile("${path.module}/userdata.sh.tpl", {
    project_name  = var.project_name
    github_repo   = var.github_repo
    openrouter_key = var.openrouter_api_key
    hermes_model  = var.hermes_model
  })

  tags = merge(local.common_tags, { Name = var.project_name })

  lifecycle {
    # Prevent accidental replacement when AMI updates
    ignore_changes = [ami, user_data]
  }
}

###############################################################
# Elastic IP — your permanent public address
###############################################################
resource "aws_eip" "hermes" {
  instance = aws_instance.hermes.id
  domain   = "vpc"
  tags     = merge(local.common_tags, { Name = "${var.project_name}-eip" })
}

###############################################################
# Locals
###############################################################
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
