# Public ALB: HTTP -> HTTPS redirect, TLS 1.2+/1.3 with an ACM certificate,
# host-based routing: api.<domain> -> API target group, portal host(s) -> web.
# Anything else gets a 404.

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate (same region) covering the API and portal hostnames."
  type        = string
}

variable "additional_certificate_arns" {
  description = "Extra ACM certificates attached via SNI."
  type        = list(string)
  default     = []
}

variable "api_domain" {
  description = "API hostname, e.g. api.carecompanion.in."
  type        = string
}

variable "portal_domains" {
  description = "Portal hostnames served by the web app (max 5 per rule)."
  type        = list(string)
}

variable "api_port" {
  description = "API container port."
  type        = number
}

variable "web_port" {
  description = "Web container port."
  type        = number
}

variable "api_health_check_path" {
  description = "API target group health check path."
  type        = string
}

variable "web_health_check_path" {
  description = "Web target group health check path."
  type        = string
}

variable "deletion_protection" {
  description = "Protect the ALB from deletion."
  type        = bool
}

variable "idle_timeout" {
  description = "Idle timeout seconds (AI replies can take ~20 s)."
  type        = number
  default     = 60
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public HTTPS"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "HTTP (redirected to HTTPS)"
}

resource "aws_vpc_security_group_egress_rule" "to_vpc" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "To targets"
}

resource "aws_lb" "this" {
  name                       = substr("${var.name}-alb", 0, 32)
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  idle_timeout               = var.idle_timeout
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
}

resource "aws_lb_target_group" "api" {
  name                 = substr("${var.name}-api", 0, 32)
  port                 = var.api_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.api_health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "web" {
  name                 = substr("${var.name}-web", 0, 32)
  port                 = var.web_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.web_health_check_path
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\":{\"code\":\"NOT_FOUND\",\"message\":\"Unknown host\"}}"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_certificate" "extra" {
  for_each        = toset(var.additional_certificate_arns)
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    host_header {
      values = [var.api_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  condition {
    host_header {
      values = var.portal_domains
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

output "arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ALB ARN suffix (CloudWatch dimension)."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "ALB DNS name (CNAME/alias target)."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "ALB hosted zone id (for Route 53 alias records)."
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "ALB security group."
  value       = aws_security_group.alb.id
}

output "api_target_group_arn" {
  description = "API target group."
  value       = aws_lb_target_group.api.arn
}

output "api_target_group_arn_suffix" {
  description = "API target group ARN suffix (CloudWatch dimension)."
  value       = aws_lb_target_group.api.arn_suffix
}

output "web_target_group_arn" {
  description = "Web target group."
  value       = aws_lb_target_group.web.arn
}

output "web_target_group_arn_suffix" {
  description = "Web target group ARN suffix (CloudWatch dimension)."
  value       = aws_lb_target_group.web.arn_suffix
}

output "https_listener_arn" {
  description = "HTTPS listener."
  value       = aws_lb_listener.https.arn
}
