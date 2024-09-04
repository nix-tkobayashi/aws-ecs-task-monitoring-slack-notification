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
