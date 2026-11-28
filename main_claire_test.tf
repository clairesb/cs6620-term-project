terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "Learner Lab only allows us-east-1 and us-west-2"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "dockerhub_user" {
  default = "clairesb"
}

variable "image_tag" {
  description = "Docker image tag to deploy, e.g. sha-e67ea5a"
  type        = string
}

# service name (must match the image name on Docker Hub) => settings
variable "services" {
  type = map(object({
    container_port    = number                  # port the app listens on in the container
    listener_port     = number                  # port you hit on the load balancer
    health_check_path = optional(string, "/health")   # must return 200-399
  }))
  default = {
    pentest = { container_port = 3000, listener_port = 80 }
    sast    = { container_port = 3000, listener_port = 8080 }
  }
}

# Credentials come from AWS_SHARED_CREDENTIALS_FILE (see .credentials/aws)
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "me" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  audit_bucket = "audit-logs-${data.aws_caller_identity.me.account_id}-${var.region}"
}

# ---------------------------------------------------------------- IAM
# Learner Lab doesn't allow creating roles, so use the pre-made LabRole
# for both ECS execution (pull image, write logs) and the task itself (S3).
data "aws_iam_role" "lab" {
  name = "LabRole"
}

# ---------------------------------------------------------------- S3

resource "terraform_data" "audit_bucket" {
  input = {
    name   = local.audit_bucket
    region = var.region
  }

  provisioner "local-exec" {
    environment = { AWS_DEFAULT_REGION = self.input.region }
    command     = <<-EOT
      aws s3api head-bucket --bucket ${self.input.name} 2>/dev/null || \
      aws s3api create-bucket --bucket ${self.input.name} \
        ${self.input.region == "us-east-1" ? "" : "--create-bucket-configuration LocationConstraint=${self.input.region}"}
    EOT
  }

  # Deletes the bucket AND its contents on `terraform destroy`.
  # Remove --force if you'd rather destroy fail on a non-empty bucket.
  provisioner "local-exec" {
    when        = destroy
    environment = { AWS_DEFAULT_REGION = self.input.region }
    command     = "aws s3 rb s3://${self.input.name} --force"
  }
}

# ---------------------------------------------------------------- VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "main" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main" }
}

# Public subnets (ALB + NAT gateway). Two AZs because an ALB requires it.
resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  tags                    = { Name = "public-${local.azs[count.index]}" }
}

# Private subnets (ECS tasks)
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  tags              = { Name = "private-${local.azs[count.index]}" }
}

# One NAT gateway (in the first public subnet) shared by all private subnets
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "main" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "public" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Free S3 gateway endpoint: audit writes go straight to S3 instead of
# through the NAT gateway (saves NAT data-processing charges).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

# ---------------------------------------------------------------- Security groups
# Load balancer: open to the internet on each listener port
resource "aws_security_group" "alb" {
  name   = "alb"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = toset([for s in var.services : s.listener_port])
    content {
      description = "listener ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # tighten to your IP if you like
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Tasks: only reachable from the load balancer
resource "aws_security_group" "svc" {
  name   = "ecs-services"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = toset([for s in var.services : s.container_port])
    content {
      description     = "container port ${ingress.value} from ALB"
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.alb.id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------- Load balancer
resource "aws_lb" "main" {
  name               = "main"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "svc" {
  for_each    = var.services
  name        = each.key
  port        = each.value.container_port
  protocol    = "HTTP"
  target_type = "ip" # required for Fargate (awsvpc)
  vpc_id      = aws_vpc.main.id

  health_check {
    path    = each.value.health_check_path
    matcher = "200-399"
  }

  deregistration_delay = 10
}

resource "aws_lb_listener" "svc" {
  for_each          = var.services
  load_balancer_arn = aws_lb.main.arn
  port              = each.value.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.svc[each.key].arn
  }
}

# ---------------------------------------------------------------- ECS
resource "aws_ecs_cluster" "main" {
  name = "main"
}

resource "aws_cloudwatch_log_group" "svc" {
  for_each          = var.services
  name              = "/ecs/${each.key}"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "svc" {
  for_each                 = var.services
  family                   = each.key
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.lab.arn
  task_role_arn            = data.aws_iam_role.lab.arn

  # If your images were built on Apple Silicon without --platform linux/amd64,
  # change this to "ARM64" (or rebuild for amd64).
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name         = each.key
    image        = "${var.dockerhub_user}/${each.key}:${var.image_tag}"
    essential    = true
    portMappings = [{ containerPort = each.value.container_port }]
    environment = [
      { name = "AUDIT_BUCKET", value = local.audit_bucket },
      { name = "AWS_REGION", value = var.region },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.svc[each.key].name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "svc" {
  for_each                          = var.services
  name                              = each.key
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.svc[each.key].arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.svc.id]
    assign_public_ip = false # outbound goes through the NAT gateway
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.svc[each.key].arn
    container_name   = each.key
    container_port   = each.value.container_port
  }

  # Tasks need the NAT route in place before they start (or the image pull
  # fails), and the audit bucket must exist before they start writing to it.
  depends_on = [
    aws_lb_listener.svc,
    aws_nat_gateway.main,
    aws_route_table_association.private,
    terraform_data.audit_bucket,
  ]
}

# ---------------------------------------------------------------- Outputs
output "audit_bucket" {
  value = local.audit_bucket
}

output "service_urls" {
  value = {
    for name, s in var.services :
    name => "http://${aws_lb.main.dns_name}${s.listener_port == 80 ? "" : ":${s.listener_port}"}"
  }
}