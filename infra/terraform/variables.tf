# ---------------------------------------------------------------- general
variable "project" {
  description = "Project slug used in every resource name."
  type        = string
  default     = "carecompanion"
}

variable "environment" {
  description = "Environment name: staging or production. Use one state file per environment."
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "region" {
  description = "AWS region. ap-south-1 (Mumbai) keeps health data in India; do not change without legal review."
  type        = string
  default     = "ap-south-1"
}

variable "azs" {
  description = "Two availability zones in the region."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
  validation {
    condition     = length(var.azs) == 2
    error_message = "Exactly two AZs are expected."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block (/16 recommended; subnets are /24)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway instead of one per AZ (cheaper; egress depends on one AZ). Recommended false in production."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for all ECS services."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------- DNS / TLS
variable "api_domain" {
  description = "Public API hostname routed to the API service, e.g. api.carecompanion.in (staging: api.staging.carecompanion.in)."
  type        = string
}

variable "portal_domains" {
  description = "Portal hostnames routed to the web service, e.g. [\"portal.carecompanion.in\"]. Also used for CORS_ORIGINS. The app-store account deletion page lives at https://<first portal domain>/account/delete."
  type        = list(string)
  validation {
    condition     = length(var.portal_domains) >= 1 && length(var.portal_domains) <= 5
    error_message = "Provide 1 to 5 portal domains."
  }
}

variable "acm_certificate_arn" {
  description = "ARN of an ISSUED ACM certificate in the same region covering api_domain and portal_domains (create it in the console with DNS validation)."
  type        = string
}

variable "additional_certificate_arns" {
  description = "Optional extra ACM certificates for the HTTPS listener (SNI)."
  type        = list(string)
  default     = []
}

variable "create_route53_records" {
  description = "Create Route 53 alias records for api_domain and portal_domains pointing at the ALB. Leave false if DNS is hosted elsewhere (then create CNAMEs to the alb_dns_name output)."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Hosted zone id used when create_route53_records = true."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------- database
variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.medium"
}

variable "db_engine_version" {
  description = "PostgreSQL version (major pins to the latest minor chosen by AWS)."
  type        = string
  default     = "16"
}

variable "db_multi_az" {
  description = "Run a synchronous Multi-AZ standby (strongly recommended for production)."
  type        = bool
  default     = true
}

variable "db_allocated_storage_gb" {
  description = "Initial gp3 storage in GB."
  type        = number
  default     = 50
}

variable "db_max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling in GB."
  type        = number
  default     = 200
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days (point-in-time recovery window)."
  type        = number
  default     = 14
}

variable "db_deletion_protection" {
  description = "Deletion protection on the database (and final snapshot on destroy)."
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Database name."
  type        = string
  default     = "carecompanion"
}

variable "db_master_username" {
  description = "RDS master username. Its password is generated and stored by RDS in Secrets Manager. The app should use its own role (see the runbook)."
  type        = string
  default     = "cc_master"
}

# ---------------------------------------------------------------- storage
variable "records_bucket_name" {
  description = "Health-records bucket name. Empty = <project>-<environment>-records-<account id>."
  type        = string
  default     = ""
}

variable "records_transition_to_ia_days" {
  description = "Move current record objects to STANDARD_IA after N days."
  type        = number
  default     = 90
}

variable "records_noncurrent_expiration_days" {
  description = "Permanently delete noncurrent object versions after N days. [REQUIRES LEGAL REVIEW] against the retention policy."
  type        = number
  default     = 365
}

# ---------------------------------------------------------------- redis
variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_num_cache_clusters" {
  description = "1 = single node (pilot); 2 = primary + replica with automatic failover."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------- containers
variable "image_tag" {
  description = "Initial image tag for the task definitions. The deploy workflow replaces it; only matters on first apply."
  type        = string
  default     = "bootstrap"
}

variable "bootstrap_mode" {
  description = "First apply only: create everything with 0 running tasks (ECR is still empty). Set false after the first images are pushed."
  type        = bool
  default     = false
}

variable "api_cpu" {
  description = "API task CPU units."
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "API task memory (MiB)."
  type        = number
  default     = 1024
}

variable "api_min_tasks" {
  description = "Minimum API tasks (>= 2 for availability across AZs)."
  type        = number
  default     = 2
  validation {
    condition     = var.api_min_tasks >= 2
    error_message = "Run at least 2 API tasks."
  }
}

variable "api_max_tasks" {
  description = "Maximum API tasks under CPU autoscaling."
  type        = number
  default     = 6
}

variable "api_cpu_target_percent" {
  description = "API autoscaling target CPU %."
  type        = number
  default     = 60
}

variable "worker_cpu" {
  description = "Worker task CPU units (same image as the API, WORKER_ENABLED=true, exactly 1 task)."
  type        = number
  default     = 256
}

variable "worker_memory" {
  description = "Worker task memory (MiB)."
  type        = number
  default     = 512
}

variable "web_cpu" {
  description = "Web task CPU units."
  type        = number
  default     = 256
}

variable "web_memory" {
  description = "Web task memory (MiB)."
  type        = number
  default     = 512
}

variable "web_min_tasks" {
  description = "Minimum web tasks."
  type        = number
  default     = 1
}

variable "web_max_tasks" {
  description = "Maximum web tasks."
  type        = number
  default     = 3
}

variable "enable_clamav" {
  description = "Run a clamd service (private DNS clamav.<namespace>:3310) and set CLAMAV_HOST on the API. Required in production (contract §27)."
  type        = bool
  default     = true
}

variable "clamav_image" {
  description = "ClamAV image. Mirror it into ECR for production to avoid Docker Hub rate limits."
  type        = string
  default     = "clamav/clamav:stable"
}

variable "clamav_cpu" {
  description = "ClamAV task CPU units."
  type        = number
  default     = 1024
}

variable "clamav_memory" {
  description = "ClamAV task memory (MiB). clamd needs ~3 GB while reloading signatures."
  type        = number
  default     = 4096
}

variable "enable_ecs_exec" {
  description = "Allow `aws ecs execute-command` into API tasks (adds ssmmessages permissions). Keep false unless debugging."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------- app config
variable "api_secret_names" {
  description = <<-EOT
    Environment variables injected into the API/worker from AWS Secrets Manager.
    Terraform creates EMPTY secrets named <project>/<environment>/api/<NAME>;
    you put the values out-of-band (aws secretsmanager put-secret-value) BEFORE
    the first task starts. A task fails to start if any listed secret has no
    value. The defaults are what NODE_ENV=production requires to boot
    (services/api/src/config.ts productionReadinessIssues) with SMS_PROVIDER=msg91
    and PAYMENT_GATEWAY=razorpay. Add optional ones when you have them:
    FCM_PRIVATE_KEY (with FCM_PROJECT_ID/FCM_CLIENT_EMAIL in api_extra_environment),
    JITSI_APP_SECRET, TWILIO_AUTH_TOKEN (if SMS_PROVIDER=twilio instead of msg91),
    REVIEW_OTP (with REVIEW_PHONE in api_extra_environment) for the App Store /
    Play reviewer demo login; remove it again after review.
  EOT
  type        = list(string)
  default = [
    "DATABASE_URL",
    "JWT_SECRET",
    "PAYMENT_WEBHOOK_SECRET",
    "RAZORPAY_KEY_SECRET",
    "RAZORPAY_WEBHOOK_SECRET",
    "MSG91_AUTH_KEY",
    "MFA_ENCRYPTION_KEY",
    "VIDEO_ROOM_SECRET",
    "METRICS_TOKEN",
    "ANTHROPIC_API_KEY",
  ]
}

variable "api_extra_environment" {
  description = "Extra NON-secret API/worker environment variables, e.g. RAZORPAY_KEY_ID, MSG91_OTP_TEMPLATE_ID, MSG91_NOTIFY_TEMPLATE_ID, MSG91_SENDER_ID, SUPPORT_PHONE, SUPPORT_EMAIL, SUPPORT_WHATSAPP, FCM_PROJECT_ID, FCM_CLIENT_EMAIL, JITSI_DOMAIN, JITSI_APP_ID, AI_MODEL, MIN_APP_VERSION_*. Overrides the defaults in main.tf (locals.api_base_environment)."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------- edge security
variable "alb_deletion_protection" {
  description = "Deletion protection on the ALB."
  type        = bool
  default     = true
}

variable "waf_rate_limit_per_5min" {
  description = "WAF: max requests per client IP per 5 minutes (whole site). Mobile carriers NAT many users behind one IP; keep generous."
  type        = number
  default     = 3000
}

variable "waf_otp_rate_limit_per_5min" {
  description = "WAF: max requests per client IP per 5 minutes to /api/v1/auth/otp/* (the API also limits per phone)."
  type        = number
  default     = 100
}

# ---------------------------------------------------------------- alarms
variable "alarm_emails" {
  description = "Emails subscribed to the CloudWatch alarm SNS topic."
  type        = list(string)
  default     = []
}

variable "api_p95_latency_alarm_seconds" {
  description = "API p95 latency alarm threshold (seconds)."
  type        = number
  default     = 1.5
}

# ---------------------------------------------------------------- CI/CD (GitHub OIDC)
variable "github_repository" {
  description = "GitHub repository allowed to deploy, as owner/name. Empty = do not create the deploy role."
  type        = string
  default     = ""
}

variable "create_github_oidc_provider" {
  description = "Create the account-wide GitHub OIDC identity provider. Set false for the second environment in the same account (it already exists)."
  type        = bool
  default     = true
}
