###############################################################
# ECS Fargate — runs the Hermes Agent container
###############################################################

# ECS Cluster
resource "aws_ecs_cluster" "hermes" {
  name = "hermes-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Project = "hermes-agent", ManagedBy = "terraform" }
}

# CloudWatch log group for container logs
resource "aws_cloudwatch_log_group" "hermes" {
  name              = "/ecs/hermes-agent"
  retention_in_days = 14

  tags = { Project = "hermes-agent" }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "hermes-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow task to pull secrets from SSM Parameter Store
resource "aws_iam_role_policy" "ecs_ssm" {
  name = "hermes-ecs-ssm-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "ssm:GetParameter"]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/hermes/*"
    }]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "hermes" {
  family                   = "hermes-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"   # 0.5 vCPU
  memory                   = "1024"  # 1 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "hermes-agent"
      image = "${aws_ecr_repository.hermes.repository_url}:latest"
      essential = true

      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]

      environment = [
        { name = "PYTHONUNBUFFERED", value = "1" }
      ]

      secrets = [
        { name = "OPENAI_API_KEY",      valueFrom = "/hermes/openai_api_key" },
        { name = "TELEGRAM_BOT_TOKEN", valueFrom = "/hermes/telegram_bot_token" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.hermes.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = { Project = "hermes-agent", ManagedBy = "terraform" }
}

# ECS Fargate Service
resource "aws_ecs_service" "hermes" {
  name            = "hermes-service"
  cluster         = aws_ecs_cluster.hermes.id
  task_definition = aws_ecs_task_definition.hermes.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.hermes.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hermes.arn
    container_name   = "hermes-agent"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  depends_on = [aws_lb_listener.hermes]

  tags = { Project = "hermes-agent", ManagedBy = "terraform" }
}
