###############################################################
# Application Load Balancer for Hermes Agent
###############################################################

# VPC (if not already defined in main.tf — adjust as needed)
resource "aws_vpc" "hermes" {
  count      = var.create_vpc ? 1 : 0
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "hermes-vpc", Project = "hermes-agent" }
}

locals {
  vpc_id = var.create_vpc ? aws_vpc.hermes[0].id : var.existing_vpc_id
}

# Public subnets across 2 AZs
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = local.vpc_id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = { Name = "hermes-public-${count.index}", Project = "hermes-agent" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Internet Gateway
resource "aws_internet_gateway" "hermes" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = local.vpc_id

  tags = { Name = "hermes-igw" }
}

# Route table → internet
resource "aws_route_table" "public" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hermes[0].id
  }

  tags = { Name = "hermes-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = var.create_vpc ? aws_route_table.public[0].id : var.existing_route_table_id
}

# Security Group: ALB
resource "aws_security_group" "alb" {
  name        = "hermes-alb-sg"
  description = "Allow HTTP/HTTPS inbound to ALB"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hermes-alb-sg" }
}

# Security Group: ECS Tasks
resource "aws_security_group" "hermes" {
  name        = "hermes-ecs-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hermes-ecs-sg" }
}

# Application Load Balancer
resource "aws_lb" "hermes" {
  name               = "hermes-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = { Project = "hermes-agent", ManagedBy = "terraform" }
}

# Target Group
resource "aws_lb_target_group" "hermes" {
  name        = "hermes-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"  # Required for Fargate

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,204"
  }

  tags = { Project = "hermes-agent" }
}

# ALB Listener (HTTP → forward)
resource "aws_lb_listener" "hermes" {
  load_balancer_arn = aws_lb.hermes.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hermes.arn
  }
}

output "alb_dns_name" {
  description = "Public URL of the Hermes Agent gateway"
  value       = "http://${aws_lb.hermes.dns_name}"
}
