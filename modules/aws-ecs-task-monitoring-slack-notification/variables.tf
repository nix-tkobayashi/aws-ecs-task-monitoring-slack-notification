variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "us-east-1"
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL"
  type        = string
}

variable "cluster_name" {
  description = "ECSクラスター名"
  type        = string
}

variable "service_name" {
  description = "ECSサービス名"
  type        = string
}

variable "container_count" {
  description = "タスク定義内のコンテナ数"
  type        = number
  default     = 1
}
