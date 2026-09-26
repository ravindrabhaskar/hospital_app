# =============================================================================
# CareCompanion AWS stack (one environment per state file), ap-south-1.
#
#   Internet -> WAF -> ALB (HTTPS, host routing)
#                        |- api.<domain>     -> ECS Fargate "api"   (>=2 tasks, CPU autoscaling)
#                        '- portal domain(s) -> ECS Fargate "web"   (Next.js standalone)
#   ECS "worker"  (same image as api, WORKER_ENABLED=true, exactly 1 task)
#   ECS "clamav"  (optional, clamd on clamav.<ns>:3310 via Cloud Map)
#   RDS PostgreSQL 16 (KMS, Multi-AZ toggle) | ElastiCache Redis (TLS) | S3 records (SSE-KMS)
#   Secrets Manager (names only) | CloudWatch logs + alarms -> SNS | GitHub OIDC deploy role
#
# See docs/runbooks/DEPLOYMENT_RUNBOOK.md for the first-deploy procedure.
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id

  records_bucket_name = var.records_bucket_name != "" ? var.records_bucket_name : "${local.name}-records-${local.account_id}"

  api_port = 4000
  web_port = 3000

  portal_origins = [for d in var.portal_domains : "https://${d}"]

  # First apply: nothing to run yet (ECR is empty).
  api_min    = var.bootstrap_mode ? 0 : var.api_min_tasks
  api_max    = var.bootstrap_mode ? 1 : var.api_max_tasks
  web_min    = var.bootstrap_mode ? 0 : var.web_min_tasks
  web_max    = var.bootstrap_mode ? 1 : var.web_max_tasks
  single_min = var.bootstrap_mode ? 0 : 1

  clamav_namespace = "${local.name}.internal"
  clamav_host      = "clamav.${local.clamav_namespace}"

  # Non-secret API/worker configuration. Names follow services/api/src/config.ts
  # (contract §21-§28). NODE_ENV=production makes the API REFUSE TO BOOT unless
  # SMS, Razorpay, ClamAV, MFA_ENCRYPTION_KEY and VIDEO_ROOM_SECRET are configured
  # (productionReadinessIssues). Override/add via var.api_extra_environment.
  api_base_environment = merge(
    {
      NODE_ENV             = "production"
      HOST                 = "0.0.0.0"
      PORT                 = tostring(local.api_port)
      API_PREFIX           = "/api/v1"
      PUBLIC_API_BASE_URL  = "https://${var.api_domain}/api/v1" # absolute profile-photo URLs (/media/:id)
      LOG_LEVEL            = "info"
      CORS_ORIGINS         = join(",", local.portal_origins)
      STORAGE_DRIVER       = "s3"
      S3_BUCKET            = module.records.bucket_name
      S3_REGION            = var.region
      S3_KMS_KEY_ID        = module.records.kms_key_arn
      REDIS_URL            = module.redis.url
      PAYMENT_GATEWAY      = "razorpay"
      SMS_PROVIDER         = "msg91"
      VIDEO_PROVIDER       = "jitsi"
      MFA_ENFORCED         = "true"
      PRIVACY_URL          = "${local.portal_origins[0]}/privacy"
      TERMS_URL            = "${local.portal_origins[0]}/terms"
      ACCOUNT_DELETION_URL = "${local.portal_origins[0]}/account/delete"
    },
    var.enable_clamav ? { CLAMAV_HOST = local.clamav_host, CLAMAV_PORT = "3310" } : {},
    var.api_extra_environment,
  )

  api_secrets = { for n in var.api_secret_names : n => aws_secretsmanager_secret.api[n].arn }

  node_health = "node -e \"fetch('http://127.0.0.1:'+(process.env.PORT)+'%s').then(r=>process.exit(r.status<500?0:1)).catch(()=>process.exit(1))\""
}

# ---------------------------------------------------------------- network
module "network" {
  source             = "./modules/network"
  name               = local.name
  cidr_block         = var.vpc_cidr
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
}

# ---------------------------------------------------------------- data stores
module "rds" {
  source                   = "./modules/rds"
  name                     = local.name
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.database_subnet_ids
  instance_class           = var.db_instance_class
  engine_version           = var.db_engine_version
  allocated_storage_gb     = var.db_allocated_storage_gb
  max_allocated_storage_gb = var.db_max_allocated_storage_gb
  multi_az                 = var.db_multi_az
  db_name                  = var.db_name
  master_username          = var.db_master_username
  backup_retention_days    = var.db_backup_retention_days
  deletion_protection      = var.db_deletion_protection
  allowed_security_groups = {
    api    = module.api.security_group_id
    worker = module.worker.security_group_id
    ops    = aws_security_group.ops.id
  }
}

module "records" {
  source                             = "./modules/records_bucket"
  bucket_name                        = local.records_bucket_name
  transition_to_ia_days              = var.records_transition_to_ia_days
  noncurrent_version_expiration_days = var.records_noncurrent_expiration_days
}

module "redis" {
  source             = "./modules/redis"
  name               = local.name
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  node_type          = var.redis_node_type
  num_cache_clusters = var.redis_num_cache_clusters
  allowed_security_groups = {
    api    = module.api.security_group_id
    worker = module.worker.security_group_id
  }
}

# ---------------------------------------------------------------- container registry
resource "aws_ecr_repository" "this" {
  for_each             = toset(["api", "web"])
  name                 = "${local.name}-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest 50 tagged images (rollback window)"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 50 }
        action       = { type = "expire" }
      },
    ]
  })
}

# ---------------------------------------------------------------- load balancer + WAF
module "alb" {
  source                      = "./modules/alb"
  name                        = local.name
  vpc_id                      = module.network.vpc_id
  public_subnet_ids           = module.network.public_subnet_ids
  certificate_arn             = var.acm_certificate_arn
  additional_certificate_arns = var.additional_certificate_arns
  api_domain                  = var.api_domain
  portal_domains              = var.portal_domains
  api_port                    = local.api_port
  web_port                    = local.web_port
  api_health_check_path       = "/api/v1/health"
  web_health_check_path       = "/login"
  deletion_protection         = var.alb_deletion_protection
}

module "waf" {
  source                  = "./modules/waf"
  name                    = local.name
  alb_arn                 = module.alb.arn
  rate_limit_per_5min     = var.waf_rate_limit_per_5min
  otp_rate_limit_per_5min = var.waf_otp_rate_limit_per_5min
}

# ---------------------------------------------------------------- secrets (names only)
# Values are NEVER in Terraform. Set them out-of-band, e.g.:
#   aws secretsmanager put-secret-value --secret-id carecompanion/production/api/JWT_SECRET \
#       --secret-string "$(openssl rand -base64 48)"
resource "aws_secretsmanager_secret" "api" {
  for_each                = toset(var.api_secret_names)
  name                    = "${var.project}/${var.environment}/api/${each.value}"
  description             = "CareCompanion ${var.environment} API env var ${each.value} (value set out-of-band)"
  recovery_window_in_days = 7
}

# ---------------------------------------------------------------- ECS cluster
resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

module "api" {
  source                    = "./modules/ecs_service"
  name                      = "${local.name}-api"
  container_name            = "api"
  cluster_arn               = aws_ecs_cluster.this.arn
  cluster_name              = aws_ecs_cluster.this.name
  image                     = "${aws_ecr_repository.this["api"].repository_url}:${var.image_tag}"
  cpu                       = var.api_cpu
  memory                    = var.api_memory
  container_port            = local.api_port
  environment               = merge(local.api_base_environment, { WORKER_ENABLED = "false" })
  secrets                   = local.api_secrets
  execution_role_arn        = aws_iam_role.execution.arn
  task_role_arn             = aws_iam_role.api_task.arn
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  ingress_security_group_id = module.alb.security_group_id
  ingress_enabled           = true
  target_group_arn          = module.alb.api_target_group_arn
  desired_count             = local.api_min
  enable_autoscaling        = true
  min_capacity              = local.api_min
  max_capacity              = local.api_max
  cpu_target_percent        = var.api_cpu_target_percent
  health_check_command      = ["CMD-SHELL", format(local.node_health, "/api/v1/health")]
  writable_paths            = ["/tmp", "/app/.data"]
  log_retention_days        = var.log_retention_days
  enable_execute_command    = var.enable_ecs_exec
}

# Background jobs (reminders, SLA checks, outbox) run in a separate 1-task
# service; the API tasks run with WORKER_ENABLED=false so request latency is
# isolated from job load. The API also elects a single job leader through a
# PostgreSQL advisory lock (WORKER_LOCK_KEY), so the brief overlap of old and
# new worker tasks during a rolling deploy cannot double-run jobs.
module "worker" {
  source                    = "./modules/ecs_service"
  name                      = "${local.name}-worker"
  container_name            = "api"
  cluster_arn               = aws_ecs_cluster.this.arn
  cluster_name              = aws_ecs_cluster.this.name
  image                     = "${aws_ecr_repository.this["api"].repository_url}:${var.image_tag}"
  cpu                       = var.worker_cpu
  memory                    = var.worker_memory
  container_port            = local.api_port
  environment               = merge(local.api_base_environment, { WORKER_ENABLED = "true" })
  secrets                   = local.api_secrets
  execution_role_arn        = aws_iam_role.execution.arn
  task_role_arn             = aws_iam_role.api_task.arn
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  ingress_security_group_id = null
  target_group_arn          = null
  desired_count             = local.single_min
  enable_autoscaling        = false
  health_check_command      = ["CMD-SHELL", format(local.node_health, "/api/v1/health")]
  writable_paths            = ["/tmp", "/app/.data"]
  log_retention_days        = var.log_retention_days
  enable_execute_command    = var.enable_ecs_exec
}

module "web" {
  source                    = "./modules/ecs_service"
  name                      = "${local.name}-web"
  container_name            = "web"
  cluster_arn               = aws_ecs_cluster.this.arn
  cluster_name              = aws_ecs_cluster.this.name
  image                     = "${aws_ecr_repository.this["web"].repository_url}:${var.image_tag}-${var.environment}"
  cpu                       = var.web_cpu
  memory                    = var.web_memory
  container_port            = local.web_port
  environment               = { NODE_ENV = "production", PORT = tostring(local.web_port), HOSTNAME = "0.0.0.0", NEXT_TELEMETRY_DISABLED = "1" }
  execution_role_arn        = aws_iam_role.execution.arn
  task_role_arn             = aws_iam_role.no_permissions.arn
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  ingress_security_group_id = module.alb.security_group_id
  ingress_enabled           = true
  target_group_arn          = module.alb.web_target_group_arn
  desired_count             = local.web_min
  enable_autoscaling        = true
  min_capacity              = local.web_min
  max_capacity              = local.web_max
  health_check_command      = ["CMD-SHELL", format(local.node_health, "/login")]
  writable_paths            = ["/tmp", "/app/.next/cache"]
  log_retention_days        = var.log_retention_days
}

# ---------------------------------------------------------------- ClamAV (optional)
resource "aws_service_discovery_private_dns_namespace" "this" {
  count       = var.enable_clamav ? 1 : 0
  name        = local.clamav_namespace
  description = "Private service discovery for ${local.name}"
  vpc         = module.network.vpc_id
}

resource "aws_service_discovery_service" "clamav" {
  count = var.enable_clamav ? 1 : 0
  name  = "clamav"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this[0].id
    routing_policy = "MULTIVALUE"
    dns_records {
      type = "A"
      ttl  = 10
    }
  }

  # ECS reports task health to Cloud Map.
  health_check_custom_config {}
}

module "clamav" {
  count                     = var.enable_clamav ? 1 : 0
  source                    = "./modules/ecs_service"
  name                      = "${local.name}-clamav"
  container_name            = "clamav"
  cluster_arn               = aws_ecs_cluster.this.arn
  cluster_name              = aws_ecs_cluster.this.name
  image                     = var.clamav_image
  cpu                       = var.clamav_cpu
  memory                    = var.clamav_memory
  container_port            = 3310
  execution_role_arn        = aws_iam_role.execution.arn
  task_role_arn             = aws_iam_role.no_permissions.arn
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  ingress_security_group_id = null
  service_registry_arn      = aws_service_discovery_service.clamav[0].arn
  desired_count             = local.single_min
  enable_autoscaling        = false
  readonly_root_filesystem  = false
  health_check_command      = ["CMD-SHELL", "clamdcheck.sh"]
  health_check_start_period = 300
  log_retention_days        = var.log_retention_days
}

resource "aws_vpc_security_group_ingress_rule" "clamav_from_app" {
  for_each = var.enable_clamav ? {
    api    = module.api.security_group_id
    worker = module.worker.security_group_id
  } : {}
  security_group_id            = module.clamav[0].security_group_id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 3310
  to_port                      = 3310
  description                  = "clamd from ${each.key}"
}

# ---------------------------------------------------------------- ops: one-off psql task
# Run with `aws ecs run-task` (see runbook) to create the app DB role and the
# first super_admin. Uses the RDS-managed master credentials; nothing is stored here.
resource "aws_security_group" "ops" {
  name        = "${local.name}-ops"
  description = "One-off admin tasks (psql)"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-ops" }
}

resource "aws_vpc_security_group_egress_rule" "ops" {
  security_group_id = aws_security_group.ops.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound (image pull, RDS)"
}

resource "aws_cloudwatch_log_group" "ops" {
  name              = "/ecs/${local.name}-ops-psql"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "ops_psql" {
  family                   = "${local.name}-ops-psql"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ops_execution.arn

  container_definitions = jsonencode([{
    name      = "psql"
    image     = "public.ecr.aws/docker/library/postgres:16-alpine"
    essential = true
    command   = ["psql", "-v", "ON_ERROR_STOP=1", "-c", "select version()"]
    environment = [
      { name = "PGHOST", value = module.rds.endpoint },
      { name = "PGPORT", value = tostring(module.rds.port) },
      { name = "PGDATABASE", value = var.db_name },
      { name = "PGSSLMODE", value = "require" },
    ]
    # APP_DATABASE_URL lets the runbook create the app role from the DATABASE_URL
    # secret without the password ever appearing in run-task overrides.
    secrets = concat(
      [
        { name = "PGUSER", valueFrom = "${module.rds.master_secret_arn}:username::" },
        { name = "PGPASSWORD", valueFrom = "${module.rds.master_secret_arn}:password::" },
      ],
      contains(var.api_secret_names, "DATABASE_URL") ? [{ name = "APP_DATABASE_URL", valueFrom = aws_secretsmanager_secret.api["DATABASE_URL"].arn }] : [],
    )
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ops.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "psql"
      }
    }
  }])
}

# ---------------------------------------------------------------- DNS (optional)
resource "aws_route53_record" "this" {
  for_each = var.create_route53_records ? toset(concat([var.api_domain], var.portal_domains)) : toset([])
  zone_id  = var.route53_zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------- monitoring
module "monitoring" {
  source                      = "./modules/monitoring"
  name                        = local.name
  alarm_emails                = var.alarm_emails
  alb_arn_suffix              = module.alb.arn_suffix
  api_target_group_arn_suffix = module.alb.api_target_group_arn_suffix
  web_target_group_arn_suffix = module.alb.web_target_group_arn_suffix
  cluster_name                = aws_ecs_cluster.this.name
  api_service_name            = module.api.service_name
  web_service_name            = module.web.service_name
  rds_instance_id             = module.rds.instance_id
  api_p95_latency_seconds     = var.api_p95_latency_alarm_seconds
}
