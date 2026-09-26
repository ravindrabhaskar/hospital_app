# Reusable Fargate service: task definition, CloudWatch log group, security
# group, optional ALB target group attachment, optional Cloud Map registration
# and optional CPU target-tracking autoscaling.
#
# IMAGE OWNERSHIP: Terraform owns the *shape* of the task definition (CPU,
# memory, env, secrets, roles). The deploy workflow owns the *image*: it copies
# the latest ACTIVE revision of the family, swaps the image and updates the
# service. Hence `ignore_changes = [task_definition, desired_count]` below.
# After a `terraform apply` that changes the task definition, run the deploy
# workflow (or `aws ecs update-service --force-new-deployment` with the new
# revision) to roll it out.

variable "name" {
  description = "Service / task family name, e.g. carecompanion-production-api."
  type        = string
}

variable "container_name" {
  description = "Container name inside the task definition (the deploy workflow targets it)."
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster ARN."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name (autoscaling resource id)."
  type        = string
}

variable "image" {
  description = "Initial container image (repo:tag). Later deploys replace it."
  type        = string
}

variable "cpu" {
  description = "Task CPU units (256 = 0.25 vCPU)."
  type        = number
}

variable "memory" {
  description = "Task memory (MiB)."
  type        = number
}

variable "container_port" {
  description = "Container port."
  type        = number
}

variable "command" {
  description = "Optional command override."
  type        = list(string)
  default     = null
}

variable "environment" {
  description = "Plain (non-secret) environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of ENV_NAME => Secrets Manager ARN (optionally ARN:json-key::) injected at task start."
  type        = map(string)
  default     = {}
}

variable "execution_role_arn" {
  description = "Task execution role (image pull, logs, secrets)."
  type        = string
}

variable "task_role_arn" {
  description = "Task role (what the app itself may call)."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the tasks."
  type        = list(string)
}

variable "ingress_security_group_id" {
  description = "Security group allowed to reach container_port (ALB or API tasks). null = no ingress."
  type        = string
  default     = null
}

variable "ingress_enabled" {
  description = "Create the ingress rule from ingress_security_group_id (a static bool keeps count plannable)."
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ALB target group to register with (null = none)."
  type        = string
  default     = null
}

variable "service_registry_arn" {
  description = "Cloud Map service ARN for private DNS discovery (null = none)."
  type        = string
  default     = null
}

variable "desired_count" {
  description = "Initial desired task count (autoscaling takes over when enabled)."
  type        = number
}

variable "enable_autoscaling" {
  description = "Enable CPU target-tracking autoscaling."
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Autoscaling minimum tasks."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Autoscaling maximum tasks."
  type        = number
  default     = 4
}

variable "cpu_target_percent" {
  description = "Target average CPU utilisation."
  type        = number
  default     = 60
}

variable "health_check_command" {
  description = "Container health check command (CMD-SHELL form). null = none."
  type        = list(string)
  default     = null
}

variable "health_check_start_period" {
  description = "Seconds before container health check failures count."
  type        = number
  default     = 60
}

variable "readonly_root_filesystem" {
  description = "Mount the root filesystem read-only."
  type        = bool
  default     = true
}

variable "writable_paths" {
  description = "Paths given an ephemeral writable volume when the root filesystem is read-only."
  type        = list(string)
  default     = ["/tmp"]
}

variable "deployment_minimum_healthy_percent" {
  description = "Rolling deploy lower bound (100 = never drop below desired)."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Rolling deploy upper bound (200 = start the new tasks before stopping old ones)."
  type        = number
  default     = 200
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 30
}

variable "enable_execute_command" {
  description = "Allow `aws ecs execute-command` (needs ssmmessages permissions on the task role)."
  type        = bool
  default     = false
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64 (must match the image)."
  type        = string
  default     = "X86_64"
}

data "aws_region" "current" {}

locals {
  volumes = var.readonly_root_filesystem ? { for i, p in var.writable_paths : "rw${i}" => p } : {}
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_security_group" "task" {
  name        = "${var.name}-task"
  description = "${var.name} tasks"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-task" }
}

resource "aws_vpc_security_group_ingress_rule" "from_source" {
  count                        = var.ingress_enabled ? 1 : 0
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = var.ingress_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "App port"
}

# Egress: HTTPS to AWS APIs / Anthropic / SMS / FCM via NAT, and VPC-internal
# traffic (RDS, Redis, ClamAV). Tighten with an egress proxy/allow-list later.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound"
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "volume" {
    for_each = local.volumes
    content {
      name = volume.key
    }
  }

  container_definitions = jsonencode([
    {
      name                   = var.container_name
      image                  = var.image
      essential              = true
      command                = var.command
      readonlyRootFilesystem = var.readonly_root_filesystem
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
        name          = "${var.container_name}-${var.container_port}"
      }]
      environment = [for k in sort(keys(var.environment)) : { name = k, value = var.environment[k] }]
      secrets     = [for k in sort(keys(var.secrets)) : { name = k, valueFrom = var.secrets[k] }]
      mountPoints = [for k, p in local.volumes : { sourceVolume = k, containerPath = p, readOnly = false }]
      healthCheck = var.health_check_command == null ? null : {
        command     = var.health_check_command
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = var.health_check_start_period
      }
      stopTimeout = 30
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.container_name
        }
      }
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  name                   = var.name
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  enable_execute_command = var.enable_execute_command
  propagate_tags         = "SERVICE"

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.target_group_arn == null ? null : 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]
    content {
      target_group_arn = load_balancer.value
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registry_arn == null ? [] : [var.service_registry_arn]
    content {
      registry_arn = service_registries.value
    }
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_appautoscaling_target" "this" {
  count              = var.enable_autoscaling ? 1 : 0
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_percent
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_family" {
  description = "Task definition family."
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_arn" {
  description = "Task definition ARN registered by Terraform."
  value       = aws_ecs_task_definition.this.arn
}

output "security_group_id" {
  description = "Task security group."
  value       = aws_security_group.task.id
}

output "log_group_name" {
  description = "CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.this.arn
}
