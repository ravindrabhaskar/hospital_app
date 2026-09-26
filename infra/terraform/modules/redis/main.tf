# ElastiCache Redis (encryption at rest + in transit) in the private subnets.
# Clients connect with rediss:// (TLS). Used for the shared rate-limit store and,
# later, the BullMQ job queue.

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets."
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Map of static label => security group id allowed on 6379."
  type        = map(string)
}

variable "node_type" {
  description = "Cache node type."
  type        = string
}

variable "num_cache_clusters" {
  description = "1 = single node; 2+ = replica with automatic failover and Multi-AZ."
  type        = number
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis"
  description = "Redis from app tasks only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-redis" }
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  for_each                     = var.allowed_security_groups
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  description                  = "Redis from ${each.key}"
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "${var.name} Redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.num_cache_clusters > 1
  multi_az_enabled           = var.num_cache_clusters > 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit   = 1
  snapshot_window            = "21:00-22:00"
  maintenance_window         = "sun:22:30-sun:23:30"
  auto_minor_version_upgrade = true
  apply_immediately          = false
}

output "primary_endpoint" {
  description = "Primary endpoint hostname."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "url" {
  description = "TLS connection URL for REDIS_URL."
  value       = "rediss://${aws_elasticache_replication_group.this.primary_endpoint_address}:6379"
}
