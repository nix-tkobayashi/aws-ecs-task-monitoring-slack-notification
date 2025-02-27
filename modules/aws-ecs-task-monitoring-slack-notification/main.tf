# Local Variables
locals {
  # リソースの命名
  connection_name = "slack-conn-${var.cluster_name}-${var.service_name}"
  destination_name = "slack-dest-${var.cluster_name}-${var.service_name}"
  role_name = "eb-api-${var.cluster_name}-${var.service_name}"
  target_id = "slack-${var.cluster_name}-${var.service_name}"
}

# CloudWatch Event Rule for ECS Task Stop Reason
resource "aws_cloudwatch_event_rule" "ecs_task_stopped" {
  name        = "ecs-stop-${var.cluster_name}-${var.service_name}"
  description = "ECS task stopped events for ${var.service_name}"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn    = ["arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"]
      group         = ["service:${var.service_name}"]
      desiredStatus = ["STOPPED"]
      lastStatus    = ["STOPPED"]
    }
  })
}

# CloudWatch Event Connection to Slack
resource "aws_cloudwatch_event_connection" "slack_connection" {
  name               = local.connection_name
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "Content-Type"
      value = "application/json"
    }
  }
}

# CloudWatch Event API Destination
resource "aws_cloudwatch_event_api_destination" "slack_api_destination" {
  name                             = local.destination_name
  description                      = "Slack notification for ${var.cluster_name}"
  connection_arn                   = aws_cloudwatch_event_connection.slack_connection.arn
  invocation_endpoint              = var.slack_webhook_url
  http_method                      = "POST"
  invocation_rate_limit_per_second = 1
}

# IAM Role for EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "invoke-api-destination"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = ["events:InvokeApiDestination"]
        Resource = aws_cloudwatch_event_api_destination.slack_api_destination.arn
      }]
    })
  }
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "slack_notification" {
  rule      = aws_cloudwatch_event_rule.ecs_task_stopped.name
  target_id = local.target_id
  arn       = aws_cloudwatch_event_api_destination.slack_api_destination.arn
  role_arn  = aws_iam_role.eventbridge_role.arn

  input_transformer {
    input_paths = merge(
      {
        "account"          = "$.account"
        "availabilityZone" = "$.detail.availabilityZone"
        "clusterArn"       = "$.detail.clusterArn"
        "resource"         = "$.resources[0]"
        "stoppedAt"        = "$.detail.stoppedAt"
        "stopCode"         = "$.detail.stopCode"
        "stoppedReason"    = "$.detail.stoppedReason"
        "startedAt"        = "$.detail.startedAt"
        "group"            = "$.detail.group"
      },
      merge([
        for i in range(var.container_count) : {
          "container${i}_name"     = "$.detail.containers[${i}].name"
          "container${i}_reason"   = "$.detail.containers[${i}].reason"
          "container${i}_exitCode" = "$.detail.containers[${i}].exitCode"
          "container${i}_ip"       = "$.detail.containers[${i}].networkInterfaces[0].privateIpv4Address"
        }
      ]...)
    )

    input_template = <<EOF
{"text": ":warning: ${var.cluster_name} の ECS タスクが停止されました :warning:\n\n*概要*\n• アカウントID : `<account>`\n• サービス名 : `<group>`\n• アベイラビリティゾーン : `<availabilityZone>`\n• 対象タスク : `<resource>`\n• 起動時間 : `<startedAt>`\n• 停止時間 : `<stoppedAt>`\n• 停止コード : `<stopCode>`\n• タスク停止理由 : `<stoppedReason>`${join("", [
  for i in range(var.container_count) :
  "\\n• コンテナ${i + 1} : `<container${i}_name>` (ExitCode: `<container${i}_exitCode>`, IP: `<container${i}_ip>`)\\n  停止理由 : `<container${i}_reason>`"
])}}
EOF
  }
}
