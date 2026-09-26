# RDS PostgreSQL 16: KMS-encrypted, TLS enforced, 14-day automated backups (PITR),
# deletion protection, Performance Insights, optional Multi-AZ.
# The master password is generated and stored by RDS in Secrets Manager
# (manage_master_user_password), so it never appears in Terraform state.

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated database subnets."
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Map of static label => security group id allowed to reach port 5432 (API tasks, ops task). Static keys keep for_each plannable."
  type        = map(string)
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage_gb" {
  description = "Initial gp3 storage in GB."
  type        = number
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling in GB."
  type        = number
}

variable "multi_az" {
  description = "Synchronous standby in a second AZ."
  type        = bool
}

variable "db_name" {
  description = "Initial database name."
  type        = string
}

variable "master_username" {
  description = "Master username (the password is managed by RDS in Secrets Manager)."
  type        = string
}

variable "backup_retention_days" {
  description = "Automated backup retention (PITR window)."
  type        = number
}

variable "deletion_protection" {
  description = "Block accidental deletion."
  type        = bool
}

variable "engine_version" {
  description = "PostgreSQL engine version (major or major.minor)."
  type        = string
}

resource "aws_kms_key" "rds" {
  description             = "${var.name} RDS + Performance Insights"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "PostgreSQL from app tasks only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "rds" {
  for_each                     = var.allowed_security_groups
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from ${each.key}"
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
  # Never log statement parameters (they can contain PHI).
  parameter {
    name  = "log_statement"
    value = "none"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-pg"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period  = var.backup_retention_days
  backup_window            = "20:00-21:00" # 01:30-02:30 IST
  maintenance_window       = "sun:21:30-sun:22:30"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-pg-final"

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  auto_minor_version_upgrade      = true
  apply_immediately               = false
  ca_cert_identifier              = "rds-ca-rsa2048-g1"
}

output "endpoint" {
  description = "Hostname of the primary."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port."
  value       = aws_db_instance.this.port
}

output "instance_id" {
  description = "DB instance identifier (CloudWatch dimension)."
  value       = aws_db_instance.this.identifier
}

output "master_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master credentials (JSON: username, password)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "RDS security group."
  value       = aws_security_group.rds.id
}

output "kms_key_arn" {
  description = "KMS key used for storage and Performance Insights."
  value       = aws_kms_key.rds.arn
}
