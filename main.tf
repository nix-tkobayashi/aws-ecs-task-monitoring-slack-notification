# CloudWatch Event Rule for ECS Task Stop Reason
resource "aws_cloudwatch_event_rule" "ecs_task_stopped" {
  name        = "ecs-task-stopped"
  description = "Captures ECS task stopped events"

  event_pattern = <<PATTERN
{
  "source": ["aws.ecs"],
  "detail-type": ["ECS Task State Change"],
  "detail": {
    "clusterArn": [
      "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
    ],
    "desiredStatus": ["STOPPED"],
    "lastStatus": ["STOPPED"]
  }
}
PATTERN
}

# CloudWatch Event API Destination to Slack
resource "aws_cloudwatch_event_api_destination" "slack_api_destination" {
  name                             = "slack-api-destination"
  description                      = "slack-api-destination"
  connection_arn                   = aws_cloudwatch_event_connection.slack_connection.arn
  invocation_endpoint              = var.slack_webhook_url
  http_method                      = "POST"
  invocation_rate_limit_per_second = 1
}

# CloudWatch Event Connection to Slack
resource "aws_cloudwatch_event_connection" "slack_connection" {
  name               = "slack-connection"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "Content-Type"
      value = "application/json"
    }
  }
}

# CloudWatch Event Target to Slack API Destination
resource "aws_cloudwatch_event_target" "ecs_task_stopped_slack" {
  rule      = aws_cloudwatch_event_rule.ecs_task_stopped.name
  target_id = "send-to-slack"
  arn       = aws_cloudwatch_event_api_destination.slack_api_destination.arn
  role_arn  = aws_iam_role.eventbridge_invoke_api_destination_role.arn
  input_transformer {
    input_paths = {
      "account"          = "$.account"
      "availabilityZone" = "$.detail.availabilityZone"
      "clusterArn"       = "$.detail.clusterArn"
      "resource"         = "$.resources[0]"
      "stoppedAt"        = "$.detail.stoppedAt"
      "stopCode"         = "$.detail.stopCode"
      "stoppedReason"    = "$.detail.stoppedReason"
      "startedAt"        = "$.detail.startedAt"
      "privateIpAddress" = "$.detail.containers[0].networkInterfaces[0].privateIpv4Address"
    }
    input_template = <<TEMPLATE
{
  "text": ":warning: ECS のタスクが停止されました :warning:\n\n*概要*\n• アカウントID： `<account>`\n• アベイラビリティゾーン： `<availabilityZone>`\n• 対象タスク： `<resource>`\n• 起動時間： `<startedAt>`\n• 停止時間： `<stoppedAt>`\n• プライベートIP： `<privateIpAddress>`\n• 停止コード： `<stopCode>`\n• 停止理由： `<stoppedReason>`\n\n*次のステップ*\n• 終了理由を確認しタスクの終了が意図したものかどうかを確認してください\n• 参考： <https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/resolve-stopped-errors.html|Amazon ECS の停止したタスクのエラーを解決する>"
}
TEMPLATE
  }
}

# IAM Role for EventBridge to invoke API Destination
resource "aws_iam_role" "eventbridge_invoke_api_destination_role" {
  name = "EventbridgeInvokeApiDestinationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy for EventBridge to invoke API Destination
resource "aws_iam_role_policy" "eventbridge_invoke_api_destination_policy" {
  name = "eventbridge-invoke-api-destination"
  role = aws_iam_role.eventbridge_invoke_api_destination_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:InvokeApiDestination"
        ]
        Resource = "${aws_cloudwatch_event_api_destination.slack_api_destination.arn}"
      }
    ]
  })
}
