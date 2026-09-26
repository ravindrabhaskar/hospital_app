# -----------------------------------------------------------------------------
# GitHub Actions -> AWS without long-lived keys (OIDC).
# The role can only be assumed by workflow jobs that run in the GitHub
# Environment named like var.environment ("staging" / "production") of
# var.github_repository. Put the role ARN (output github_deploy_role_arn) in
# that GitHub Environment as the variable AWS_DEPLOY_ROLE_ARN.
# -----------------------------------------------------------------------------

locals {
  create_deploy_role = var.github_repository != ""
  github_oidc_url    = "token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = local.create_deploy_role && var.create_github_oidc_provider ? 1 : 0
  url            = "https://${local.github_oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = local.create_deploy_role && !var.create_github_oidc_provider ? 1 : 0
  url   = "https://${local.github_oidc_url}"
}

locals {
  github_oidc_provider_arn = !local.create_deploy_role ? "" : (
    var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  )
}

data "aws_iam_policy_document" "github_assume" {
  count = local.create_deploy_role ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  count                = local.create_deploy_role ? 1 : 0
  name                 = "${local.name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_assume[0].json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_deploy" {
  count = local.create_deploy_role ? 1 : 0

  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [for r in aws_ecr_repository.this : r.arn]
  }

  statement {
    sid       = "TaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition", "ecs:ListTaskDefinitions", "ecs:DescribeTasks"]
    resources = ["*"]
  }

  statement {
    sid     = "UpdateServices"
    actions = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [
      "arn:aws:ecs:${var.region}:${local.account_id}:service/${aws_ecs_cluster.this.name}/*",
    ]
  }

  statement {
    sid       = "RunMigrationTask"
    actions   = ["ecs:RunTask"]
    resources = ["arn:aws:ecs:${var.region}:${local.account_id}:task-definition/${local.name}-api:*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.this.arn]
    }
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.api_task.arn, aws_iam_role.no_permissions.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "ReadMigrationLogs"
    actions   = ["logs:GetLogEvents", "logs:FilterLogEvents"]
    resources = ["${replace(module.api.log_group_arn, ":*", "")}:*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  count  = local.create_deploy_role ? 1 : 0
  name   = "deploy"
  role   = aws_iam_role.github_deploy[0].id
  policy = data.aws_iam_policy_document.github_deploy[0].json
}
