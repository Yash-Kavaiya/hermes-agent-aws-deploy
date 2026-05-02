###############################################################
# ECR Repository for Hermes Agent Docker images
###############################################################
resource "aws_ecr_repository" "hermes" {
  name                 = "hermes-agent"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = "hermes-agent"
    ManagedBy   = "terraform"
  }
}

# Lifecycle policy: keep only the last 10 tagged images to control costs
resource "aws_ecr_lifecycle_policy" "hermes" {
  repository = aws_ecr_repository.hermes.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only last 10 sha-tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "ecr_repository_url" {
  description = "ECR repository URL for CI/CD"
  value       = aws_ecr_repository.hermes.repository_url
}
