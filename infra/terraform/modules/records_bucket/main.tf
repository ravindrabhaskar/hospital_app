# Health-records bucket: SSE-KMS with a dedicated CMK, Block Public Access,
# versioning, TLS-only policy, lifecycle tiering. Objects are write-once in the
# app (originals are immutable); versioning protects against overwrite/delete.

variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent (overwritten/deleted) versions are permanently removed."
  type        = number
}

variable "transition_to_ia_days" {
  description = "Days after which current objects move to STANDARD_IA."
  type        = number
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket. Keep false outside throwaway stacks."
  type        = bool
  default     = false
}

resource "aws_kms_key" "records" {
  description             = "${var.bucket_name} SSE-KMS"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "records" {
  name          = "alias/${var.bucket_name}"
  target_key_id = aws_kms_key.records.key_id
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.records.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket     = aws_s3_bucket.this.id
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "tier-current-objects"
    status = "Enabled"
    filter {}
    transition {
      days          = var.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER_IR"
    }
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.this]
}

output "bucket_name" {
  description = "Bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "kms_key_arn" {
  description = "CMK ARN used for SSE-KMS."
  value       = aws_kms_key.records.arn
}
