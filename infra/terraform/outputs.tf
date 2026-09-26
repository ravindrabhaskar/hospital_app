output "alb_dns_name" {
  description = "Point api_domain and portal_domains here (CNAME, or alias A if the zone is in Route 53)."
  value       = module.alb.dns_name
}

output "api_url" {
  description = "Public API base URL (use as API_BASE_URL for the mobile apps and NEXT_PUBLIC_API_BASE_URL for the web build)."
  value       = "https://${var.api_domain}/api/v1"
}

output "portal_url" {
  description = "Portal URL. Account deletion page: <portal_url>/account/delete."
  value       = "https://${var.portal_domains[0]}"
}

output "ecs_cluster_name" {
  description = "ECS cluster (GitHub environment variable ECS_CLUSTER)."
  value       = aws_ecs_cluster.this.name
}

output "ecs_services" {
  description = "ECS service names."
  value = {
    api    = module.api.service_name
    worker = module.worker.service_name
    web    = module.web.service_name
    clamav = var.enable_clamav ? module.clamav[0].service_name : null
  }
}

output "task_families" {
  description = "Task definition families (the deploy workflow registers new revisions of these)."
  value = {
    api      = module.api.task_family
    worker   = module.worker.task_family
    web      = module.web.task_family
    ops_psql = aws_ecs_task_definition.ops_psql.family
  }
}

output "ecr_repositories" {
  description = "ECR repository URLs."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "private_subnet_ids" {
  description = "Private subnets (for aws ecs run-task --network-configuration)."
  value       = module.network.private_subnet_ids
}

output "api_security_group_id" {
  description = "API task security group (migration one-off task uses it)."
  value       = module.api.security_group_id
}

output "ops_security_group_id" {
  description = "Security group for the one-off psql task."
  value       = aws_security_group.ops.id
}

output "api_secret_names" {
  description = "Secrets Manager secrets you must fill before the first deploy."
  value       = [for s in aws_secretsmanager_secret.api : s.name]
}

output "rds_endpoint" {
  description = "RDS hostname (for DATABASE_URL)."
  value       = module.rds.endpoint
}

output "rds_master_secret_arn" {
  description = "RDS-managed master credential secret (used only by the ops psql task)."
  value       = module.rds.master_secret_arn
}

output "records_bucket" {
  description = "Health-records bucket."
  value       = module.records.bucket_name
}

output "redis_url" {
  description = "REDIS_URL injected into the API."
  value       = module.redis.url
}

output "alarm_topic_arn" {
  description = "SNS topic receiving CloudWatch alarms."
  value       = module.monitoring.sns_topic_arn
}

output "github_deploy_role_arn" {
  description = "Set as GitHub Environment variable AWS_DEPLOY_ROLE_ARN."
  value       = local.create_deploy_role ? aws_iam_role.github_deploy[0].arn : null
}
