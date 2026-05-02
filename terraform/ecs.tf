###############################################################
# ECS Fargate — runs the Hermes Agent container
# Auth to Bedrock is via IAM Task Role — no API keys needed
###############################################################

resource "aws_ecs_cluster" "hermes" {
  name = "hermes-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Project = "hermes-agent", ManagedBy = "terraform" }
}

resource "aws_cloudwatch_log_group" "hermes" {
  name              = "/ecs/hermes-agent"
  retention_in_days = 14
  tags              = { Project = "hermes-agent" }
}

# Task Execution Role (pull image from ECR, write logs)
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

# ECS Task Definition
# task_role_arn  = ecs_task role (Bedrock + SSM access, used AT RUNTIME)
# execution_role = ecs_task_execution role (ECR pull + CloudWatch, used at LAUNCH)
resource "aws_ecs_task_definition" "hermes" {
  family                   = "hermes-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn  # <-- Bedrock access

  container_definitions = jsonencode([
    {
      name      = "hermes-agent"
      image     = "${aws_ecr_repository.hermes.repository_url}:latest"
      essential = true

      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]

      environment = [
        { name = "PYTHONUNBUFFERED",  value = "1" },
        { name = "AWS_REGION",        value = var.aws_region },
        # Tells Hermes to use Bedrock — auth comes from the IAM task role
        { name = "HERMES_MODEL",      value = "bedrock:anthropic.claude-3-5-sonnet-20241022-v2:0" },
        { name = "AWS_DEFAULT_REGION", value = var.aws_region }
      ]

      # Only Telegram token is a secret — Bedrock needs NO API key
      secrets = [
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

resource "aws_ecs_service" "hermes" {
  name            = "hermes-service"
  cluster         = aws_ecs_cluster.hermes.id
  task_definition = aws_ecs_task_definition.hermes.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
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
