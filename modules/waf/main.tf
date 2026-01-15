locals {
  waf_name = var.name != "" ? var.name : "${var.project_name}-${var.env}-waf"
}

resource "aws_wafv2_web_acl" "this" {
  name        = local.waf_name
  description = var.description
  scope       = "REGIONAL" # ALB는 REGIONAL

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.waf_name}-webacl"
    sampled_requests_enabled   = true
  }

  # 1) AWSManagedRulesCommonRuleSet
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    dynamic "override_action" {
      for_each = var.count_mode ? [1] : []
      content {
        count {}
      }
    }
    dynamic "override_action" {
      for_each = var.count_mode ? [] : [1]
      content {
        none {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-common"
      sampled_requests_enabled   = true
    }
  }

  # 2) AWSManagedRulesKnownBadInputsRuleSet
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    dynamic "override_action" {
      for_each = var.count_mode ? [1] : []
      content {
        count {}
      }
    }
    dynamic "override_action" {
      for_each = var.count_mode ? [] : [1]
      content {
        none {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-knownbad"
      sampled_requests_enabled   = true
    }
  }

  # 3) AWSManagedRulesAmazonIpReputationList
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 30

    dynamic "override_action" {
      for_each = var.count_mode ? [1] : []
      content {
        count {}
      }
    }
    dynamic "override_action" {
      for_each = var.count_mode ? [] : [1]
      content {
        none {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-iprep"
      sampled_requests_enabled   = true
    }
  }

  # 4) AWSManagedRulesAnonymousIpList
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 40

    dynamic "override_action" {
      for_each = var.count_mode ? [1] : []
      content {
        count {}
      }
    }
    dynamic "override_action" {
      for_each = var.count_mode ? [] : [1]
      content {
        none {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-anonip"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags
}

# (선택) ALB 연결
resource "aws_wafv2_web_acl_association" "alb" {
  count = var.associate_to_alb && var.alb_arn != "" ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# (선택) WAF 로깅
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = var.log_destination_arns

  depends_on = [aws_wafv2_web_acl.this]
}
