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
