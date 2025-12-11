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

  container_definitions = jsonencode([
    {
      name      = "yohei-app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
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
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.task_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "yohei-app"
    container_port   = var.server_port
  }

  depends_on = [aws_lb_listener.http]
}
