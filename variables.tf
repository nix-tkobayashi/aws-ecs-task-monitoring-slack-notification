# Local Variables
locals {}

# Slack Webhook URL
variable "slack_webhook_url" {
  type = string
}

# AWS Region
variable "aws_region" {
  type = string
}

# ECS Cluster Name
variable "cluster_name" {
  type = string
}

# ECS Service Name
variable "service_name" {
  description = "ECSサービス名"
  type        = string
}

# Container Count
variable "container_count" {
  description = "タスク定義内のコンテナ数"
  type        = number
  default     = 1
}
