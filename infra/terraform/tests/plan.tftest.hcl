# Credential-free plan/apply against a mocked AWS provider (Terraform >= 1.7).
# Catches plan-time errors (unknown for_each/count, bad references) in CI:
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { region = "ap-south-1", name = "ap-south-1" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:ap-south-1:123456789012:secret:rds-master", kms_key_id = "k", secret_status = "active" }]
    }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" }
  }
  mock_resource "aws_ecs_cluster" {
    defaults = { arn = "arn:aws:ecs:ap-south-1:123456789012:cluster/mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:ap-south-1:123456789012:log-group:/ecs/mock" }
  }
  mock_resource "aws_ecr_repository" {
    defaults = { arn = "arn:aws:ecr:ap-south-1:123456789012:repository/mock", repository_url = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/mock" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:ap-south-1:123456789012:secret:mock" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:ap-south-1:123456789012:key/mock" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock" }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:ap-south-1:123456789012:loadbalancer/app/mock/1" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/mock/1" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:ap-south-1:123456789012:listener/app/mock/1/1" }
  }
  mock_resource "aws_wafv2_web_acl" {
    defaults = { arn = "arn:aws:wafv2:ap-south-1:123456789012:regional/webacl/mock/1" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:ap-south-1:123456789012:mock" }
  }
  mock_resource "aws_service_discovery_service" {
    defaults = { arn = "arn:aws:servicediscovery:ap-south-1:123456789012:service/srv-mock" }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = { arn = "arn:aws:ecs:ap-south-1:123456789012:task-definition/mock:1" }
  }
}

variables {
  environment            = "production"
  api_domain             = "api.example.in"
  portal_domains         = ["portal.example.in"]
  acm_certificate_arn    = "arn:aws:acm:ap-south-1:123456789012:certificate/x"
  github_repository      = "org/repo"
  alarm_emails           = ["a@example.in"]
  create_route53_records = true
  route53_zone_id        = "Z123"
}

run "plan_production" {
  command = plan
}

run "apply_production_mocked" {
  command = apply
}

run "plan_staging_minimal" {
  command = plan
  variables {
    environment            = "staging"
    enable_clamav          = false
    bootstrap_mode         = true
    github_repository      = ""
    create_route53_records = false
    db_multi_az            = false
  }
}
