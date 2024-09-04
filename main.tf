# module
module "aws-ecs-task-monitoring-slack-notification" {
  source            = "./modules/aws-ecs-task-monitoring-slack-notification"
  aws_region        = var.aws_region
  slack_webhook_url = var.slack_webhook_url
  cluster_name      = var.cluster_name
}
