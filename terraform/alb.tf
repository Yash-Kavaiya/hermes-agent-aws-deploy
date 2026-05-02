###############################################################
# Application Load Balancer for Hermes Agent (ECS/Fargate)
# Note: The existing aws_security_group "hermes" in main.tf is
# for the EC2 deployment. This file uses distinct names.
###############################################################

# Public subnets across 2 AZs (for ALB + Fargate)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = { Name = "hermes-public-${count.index}", Project = "hermes-agent" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Internet Gateway (attach to default VPC)
resource "aws_internet_gateway" "hermes" {
  vpc_id = data.aws_vpc.default.id

  tags = { Name = "hermes-igw" }
}

# Route table → internet for the new public subnets
resource "aws_route_table" "hermes_public" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hermes.id
  }

  tags = { Name = "hermes-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.hermes_public.id
}

# Security Group: ALB (distinct name from EC2 SG in main.tf)
resource "aws_security_group" "alb" {
  name        = "hermes-alb-sg"
  description = "Allow HTTP/HTTPS inbound to ALB"
  vpc_id      = data.aws_vpc.default.id

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

# Security Group: ECS Tasks (distinct name — "ecs_tasks" not "hermes")
resource "aws_security_group" "ecs_tasks" {
  name        = "hermes-ecs-sg"
  description = "Allow traffic from ALB to ECS tasks on port 8080"
  vpc_id      = data.aws_vpc.default.id

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
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

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

# ALB Listener
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
