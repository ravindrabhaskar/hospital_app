# CloudWatch alarms -> SNS topic. Alarm names/descriptions never contain PHI.
# Subscribe email (below), or hook the topic to PagerDuty/Opsgenie/Slack (AWS Chatbot).

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "alarm_emails" {
  description = "Email addresses subscribed to the alarm topic (each must confirm the subscription)."
  type        = list(string)
  default     = []
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix."
  type        = string
}

variable "api_target_group_arn_suffix" {
  description = "API target group ARN suffix."
  type        = string
}

variable "web_target_group_arn_suffix" {
  description = "Web target group ARN suffix."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "api_service_name" {
  description = "API ECS service name."
  type        = string
}

variable "web_service_name" {
  description = "Web ECS service name."
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier."
  type        = string
}

variable "api_5xx_rate_percent" {
  description = "Alarm when API 5xx responses exceed this % of requests (5-minute windows)."
  type        = number
  default     = 2
}

variable "api_p95_latency_seconds" {
  description = "Alarm when API p95 target response time exceeds this (AI calls included, so above the 500 ms SLO for plain reads)."
  type        = number
  default     = 1.5
}

variable "cpu_percent" {
  description = "Alarm when ECS service average CPU exceeds this for 15 minutes."
  type        = number
  default     = 85
}

variable "rds_free_storage_bytes" {
  description = "Alarm when RDS free storage drops below this many bytes."
  type        = number
  default     = 10737418240 # 10 GiB
}

resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alarm_emails)
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

locals {
  actions = [aws_sns_topic.alarms.arn]
  tg_dims = {
    api = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.api_target_group_arn_suffix }
    web = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.web_target_group_arn_suffix }
  }
  services = {
    api = var.api_service_name
    web = var.web_service_name
  }
}

# ---- API 5xx rate (metric math) -------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "api_5xx_rate" {
  alarm_name          = "${var.name}-api-5xx-rate"
  alarm_description   = "API 5xx > ${var.api_5xx_rate_percent}% of requests for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.api_5xx_rate_percent
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions

  metric_query {
    id          = "rate"
    expression  = "IF(requests > 20, 100 * errors / requests, 0)"
    label       = "5xx %"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = local.tg_dims.api
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = local.tg_dims.api
      period      = 300
      stat        = "Sum"
    }
  }
}

# ALB-generated 5xx (502/503/504: no healthy targets, timeouts).
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "Load balancer generated more than 10 5xx responses in 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---- API p95 latency -------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "api_p95_latency" {
  alarm_name          = "${var.name}-api-p95-latency"
  alarm_description   = "API p95 response time > ${var.api_p95_latency_seconds}s for 15 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = local.tg_dims.api
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = var.api_p95_latency_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---- Unhealthy hosts (api + web) ------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  for_each            = local.tg_dims
  alarm_name          = "${var.name}-${each.key}-unhealthy-hosts"
  alarm_description   = "${each.key} target group has unhealthy targets for 10 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = each.value
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  for_each            = local.tg_dims
  alarm_name          = "${var.name}-${each.key}-no-healthy-hosts"
  alarm_description   = "${each.key} target group has NO healthy targets (outage)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = each.value
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---- ECS CPU ----------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each            = local.services
  alarm_name          = "${var.name}-${each.key}-cpu-high"
  alarm_description   = "${each.key} service CPU > ${var.cpu_percent}% for 15 minutes (autoscaling at max?)"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.cluster_name, ServiceName = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.cpu_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---- RDS ----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name}-rds-free-storage-low"
  alarm_description   = "RDS free storage below threshold"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.rds_free_storage_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu-high"
  alarm_description   = "RDS CPU > 80% for 15 minutes"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

output "sns_topic_arn" {
  description = "Alarm topic ARN."
  value       = aws_sns_topic.alarms.arn
}
