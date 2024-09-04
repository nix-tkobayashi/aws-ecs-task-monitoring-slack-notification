# AWS Region
data "aws_region" "current" {}

# AWS Account ID
data "aws_caller_identity" "current" {}
