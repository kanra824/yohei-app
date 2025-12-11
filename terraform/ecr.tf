# --- ECR Repository -----------------------------------------------------
resource "aws_ecr_repository" "app" {
  name = "yohei-app"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}
