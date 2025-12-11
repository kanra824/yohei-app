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