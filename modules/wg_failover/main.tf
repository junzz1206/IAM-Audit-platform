terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

locals {
  common_tags = merge(var.tags, {
    Env       = var.env
    ManagedBy = "Terraform"
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-${var.env}-wg-failover-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "failover_policy" {
  name        = "${var.name_prefix}-${var.env}-wg-failover-policy"
  description = "Allow Lambda to move EIP and replace route to standby ENI"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses",
          "ec2:ReplaceRoute",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNetworkInterfaces"
        ],
        Resource = "*"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "failover_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.failover_policy.arn
}

resource "aws_lambda_function" "failover" {
  function_name = "${var.name_prefix}-${var.env}-wg-failover"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handler"
  runtime       = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout = 30

  environment {
    variables = {
      EIP_ALLOCATION_ID = var.eip_allocation_id
      ROUTE_TABLE_ID    = var.route_table_id
      DEST_CIDR         = var.dest_cidr
      STANDBY_ENI_ID    = var.standby_eni_id
    }
  }

  tags = local.common_tags
}

# CloudWatch Alarm: Active instance status check fail -> invoke lambda
resource "aws_cloudwatch_metric_alarm" "active_failed" {
  alarm_name          = "${var.name_prefix}-${var.env}-wg-active-statuscheck-failed"
  alarm_description   = "Trigger failover when active VPN EC2 fails instance status checks"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_Instance"
  statistic           = "Maximum"
  period              = var.alarm_period
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = 1 
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.active_instance_id
  }

  alarm_actions = [aws_lambda_function.failover.arn]
  tags          = local.common_tags
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover.function_name

  principal     = "cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.active_failed.arn

  source_account = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}