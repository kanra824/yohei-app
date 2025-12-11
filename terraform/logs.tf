# --- CloudWatch Logs ----------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/yohei-app"
  retention_in_days = 14
}
