locals {
  waf_name = var.name != "" ? var.name : "${var.project_name}-${var.env}-waf"

  # count_mode에 따라 override_action을 스위칭
  override_action = var.count_mode ? "count" : "none"
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
    metric_name                = local.waf_name
    sampled_requests_enabled   = true
  }

  ############################################
  # ✅ 너희가 콘솔에서 넣어둔 Managed Rules 4종
  ############################################

  # 1) KnownBadInputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 10

    override_action {
      # count_mode=true면 count, 아니면 none
      # (none이면 managed rule group의 기본 액션 사용)
      dynamic "count" {
        for_each = local.override_action == "count" ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = local.override_action == "none" ? [1] : []
        content {}
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
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # 2) CommonRuleSet
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 20

    override_action {
      dynamic "count" { for_each = local.override_action == "count" ? [1] : []; content {} }
      dynamic "none"  { for_each = local.override_action == "none"  ? [1] : []; content {} }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 3) AmazonIpReputationList
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 30

    override_action {
      dynamic "count" { for_each = local.override_action == "count" ? [1] : []; content {} }
      dynamic "none"  { for_each = local.override_action == "none"  ? [1] : []; content {} }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AmazonIpReputation"
      sampled_requests_enabled   = true
    }
  }

  # 4) AnonymousIpList
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 40

    override_action {
      dynamic "count" { for_each = local.override_action == "count" ? [1] : []; content {} }
      dynamic "none"  { for_each = local.override_action == "none"  ? [1] : []; content {} }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags
}

# (선택) WAF 로깅
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  resource_arn = aws_wafv2_web_acl.this.arn

  log_destination_configs = var.log_destination_arns

  depends_on = [aws_wafv2_web_acl.this]
}