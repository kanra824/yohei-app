provider "aws" {
    region = "ap-northeast-1"
}

variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
    default = 8080
}

output "ecr_repository_url" {
    value = aws_ecr_repository.app.repository_url
    description = "The URL of the ECR repository"
}

# ECR Repository
resource "aws_ecr_repository" "app" {
    name = "yohei-app"

    image_tag_mutability = "MUTABLE"
    image_scanning_configuration {
        scan_on_push = false
    }
}

# --- Networking (VPC, subnets, IGW, route table) -------------------------
data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
    cidr_block = "10.0.0.0/16"
    tags = { Name = "yohei-app-vpc" }
}

resource "aws_subnet" "public" {
    count                   = 2
    vpc_id                  = aws_vpc.this.id
    cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
    availability_zone       = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = true
    tags = { Name = "yohei-app-public-${count.index}" }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.this.id
    tags = { Name = "yohei-app-igw" }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = { Name = "yohei-app-public-rt" }
}

resource "aws_route_table_association" "public" {
    count          = length(aws_subnet.public)
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

# --- Security groups ----------------------------------------------------
resource "aws_security_group" "alb_sg" {
    name   = "yohei-app-alb-sg"
    vpc_id = aws_vpc.this.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "yohei-app-alb-sg" }
}

resource "aws_security_group" "task_sg" {
    name   = "yohei-app-task-sg"
    vpc_id = aws_vpc.this.id

    ingress {
        from_port       = var.server_port
        to_port         = var.server_port
        protocol        = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "yohei-app-task-sg" }
}

# --- ALB + target group + listener -------------------------------------
resource "aws_lb" "alb" {
    name               = "yohei-app-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb_sg.id]
    subnets            = aws_subnet.public[*].id
    tags = { Name = "yohei-app-alb" }
}

resource "aws_lb_target_group" "tg" {
    name     = "yohei-app-tg"
    port     = var.server_port
    protocol = "HTTP"
    vpc_id   = aws_vpc.this.id
    target_type = "ip"
    health_check {
        path = "/"
        interval = 30
        timeout  = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
    }
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.alb.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.tg.arn
    }
}

# --- CloudWatch logs ---------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
    name              = "/ecs/yohei-app"
    retention_in_days = 14
}

# --- IAM roles for ECS task execution ----------------------------------
resource "aws_iam_role" "ecs_task_execution" {
    name = "yohei-app-ecs-exec-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Principal = { Service = "ecs-tasks.amazonaws.com" }
                Effect = "Allow"
                Sid = ""
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
    role       = aws_iam_role.ecs_task_execution.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- ECS Cluster, Task Definition, Service ------------------------------
resource "aws_ecs_cluster" "this" {
    name = "yohei-app-cluster"
}

resource "aws_ecs_task_definition" "app" {
    family                   = "yohei-app"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = "256"
    memory                   = "512"
    execution_role_arn       = aws_iam_role.ecs_task_execution.arn
    container_definitions    = jsonencode([
        {
            name  = "yohei-app"
            image = "${aws_ecr_repository.app.repository_url}:latest"
            essential = true
            portMappings = [
                {
                    containerPort = var.server_port
                    hostPort      = var.server_port
                    protocol      = "tcp"
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    "awslogs-group"         = aws_cloudwatch_log_group.app.name
                    "awslogs-region"        = "ap-northeast-1"
                    "awslogs-stream-prefix" = "yohei-app"
                }
            }
        }
    ])
}

resource "aws_ecs_service" "app" {
    name            = "yohei-app-service"
    cluster         = aws_ecs_cluster.this.id
    task_definition = aws_ecs_task_definition.app.arn
    desired_count   = 1
    launch_type     = "FARGATE"

    network_configuration {
        subnets         = aws_subnet.public[*].id
        security_groups = [aws_security_group.task_sg.id]
        assign_public_ip = true
    }

    load_balancer {
        target_group_arn = aws_lb_target_group.tg.arn
        container_name   = "yohei-app"
        container_port   = var.server_port
    }

    depends_on = [aws_lb_listener.http]
}

# --- Outputs -----------------------------------------------------------
output "alb_dns_name" {
    value = aws_lb.alb.dns_name
}

output "ecs_cluster_name" {
    value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
    value = aws_ecs_service.app.name
}