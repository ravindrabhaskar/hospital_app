# AWS WAFv2 (regional) on the ALB: AWS managed rule groups + rate limits.
# CommonRuleSet's SizeRestrictions_BODY (8 KB) would block record/photo uploads
# (MAX_UPLOAD_MB=15), so that one rule is set to COUNT; the API enforces the size.

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "alb_arn" {
  description = "ALB to protect."
  type        = string
}

variable "rate_limit_per_5min" {
  description = "Max requests per client IP per 5 minutes across the whole site."
  type        = number
}

variable "otp_rate_limit_per_5min" {
  description = "Max requests per client IP per 5 minutes to /api/v1/auth/otp/* (OTP abuse / SMS pumping)."
  type        = number
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.name}-alb"
  description = "CareCompanion ALB protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-ip-reputation"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-common"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-known-bad-inputs"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-sqli"
    priority = 40
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sqli"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit-otp"
    priority = 50
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.otp_rate_limit_per_5min
        aggregate_key_type = "IP"
        scope_down_statement {
          byte_match_statement {
            search_string         = "/api/v1/auth/otp/"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-otp"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit-global"
    priority = 60
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-global"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-alb"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

output "web_acl_arn" {
  description = "WAF web ACL ARN."
  value       = aws_wafv2_web_acl.this.arn
}
