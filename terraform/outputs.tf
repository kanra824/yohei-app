output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "The URL of the ECR repository"
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "The DNS name of the Application Load Balancer"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "The name of the ECS cluster"
}

output "ecs_service_name" {
  value       = aws_ecs_service.app.name
  description = "The name of the ECS service"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "ARN of the IAM role for GitHub Actions to assume for ECR push and ECS deployment"
}

output "github_actions_role_name" {
  value       = aws_iam_role.github_actions_role.name
  description = "Name of the IAM role for GitHub Actions"
}
