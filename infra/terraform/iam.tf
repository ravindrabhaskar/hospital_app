# ---------------------------------------------------------------- ECS roles
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ecs:${var.region}:${local.account_id}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

# Execution role: used by the ECS agent (not the app) to pull images, write
# logs and read the API secrets at task start.
resource "aws_iam_role" "execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    sid       = "ReadApiSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [for s in aws_secretsmanager_secret.api : s.arn]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "read-api-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

# Separate execution role for the one-off psql task: only it can read the RDS master secret.
resource "aws_iam_role" "ops_execution" {
  name               = "${local.name}-ops-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "ops_execution_managed" {
  role       = aws_iam_role.ops_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ops_execution_secret" {
  statement {
    sid     = "ReadRdsMasterAndAppDbSecret"
    actions = ["secretsmanager:GetSecretValue"]
    resources = concat(
      [module.rds.master_secret_arn],
      contains(var.api_secret_names, "DATABASE_URL") ? [aws_secretsmanager_secret.api["DATABASE_URL"].arn] : [],
    )
  }
}

resource "aws_iam_role_policy" "ops_execution_secret" {
  name   = "read-rds-master-secret"
  role   = aws_iam_role.ops_execution.id
  policy = data.aws_iam_policy_document.ops_execution_secret.json
}

# API/worker task role: LEAST PRIVILEGE = the records bucket + its KMS key only.
resource "aws_iam_role" "api_task" {
  name               = "${local.name}-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "api_task" {
  statement {
    sid       = "RecordsBucketList"
    actions   = ["s3:ListBucket"]
    resources = [module.records.bucket_arn]
  }

  statement {
    sid = "RecordsObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${module.records.bucket_arn}/*"]
  }

  statement {
    sid       = "RecordsKms"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [module.records.kms_key_arn]
  }

  dynamic "statement" {
    for_each = var.enable_ecs_exec ? [1] : []
    content {
      sid = "EcsExec"
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "api_task" {
  name   = "records-bucket-and-key"
  role   = aws_iam_role.api_task.id
  policy = data.aws_iam_policy_document.api_task.json
}

# Web and ClamAV call no AWS APIs.
resource "aws_iam_role" "no_permissions" {
  name               = "${local.name}-task-no-permissions"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}
