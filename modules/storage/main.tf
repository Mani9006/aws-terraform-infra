# ---------------------------------------------------------------------------
# Storage Module - Main Configuration
# ---------------------------------------------------------------------------
# Provisions S3 buckets with encryption, versioning, lifecycle policies,
# access logging, and comprehensive security controls.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Local Values
# ---------------------------------------------------------------------------

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : "${var.project_name}-assets-${var.environment}-${random_id.bucket_suffix.hex}"
}

# ---------------------------------------------------------------------------
# Random Suffix for Bucket Name
# ---------------------------------------------------------------------------

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# KMS Key for S3 Encryption
# ---------------------------------------------------------------------------

resource "aws_kms_key" "s3" {
  count = var.enable_encryption && var.encryption_type == "SSE-KMS" ? 1 : 0

  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true
  multi_region            = var.environment == "prod"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_kms_alias" "s3" {
  count = var.enable_encryption && var.encryption_type == "SSE-KMS" ? 1 : 0

  name          = "alias/${var.project_name}-s3-${var.environment}"
  target_key_id = aws_kms_key.s3[0].key_id
}

# ---------------------------------------------------------------------------
# Logging Bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = "${var.project_name}-logs-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-logs-${var.environment}"
  })

  force_destroy = var.force_destroy && var.environment != "prod"
}

resource "aws_s3_bucket_versioning" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs[0].arn}/access-logs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "ALBAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root" # us-east-1 ELB account
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs[0].arn}/alb-logs/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# ---------------------------------------------------------------------------
# Main S3 Bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })

  force_destroy = var.force_destroy && var.environment != "prod"

  object_lock_enabled = var.enable_object_lock ? true : false
}

# ---------------------------------------------------------------------------
# Bucket Versioning
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# ---------------------------------------------------------------------------
# Bucket Encryption
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  count = var.enable_encryption ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type == "SSE-KMS" ? "aws:kms" : "AES256"
      kms_master_key_id = var.encryption_type == "SSE-KMS" ? aws_kms_key.s3[0].arn : null
    }
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------------------
# Public Access Block
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

# ---------------------------------------------------------------------------
# Bucket Policy
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "main" {
  count = length(var.bucket_policy_statements) > 0 ? 1 : 0

  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "DenyUnencryptedUploads"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:PutObject"
          Resource  = "${aws_s3_bucket.main.arn}/*"
          Condition = {
            StringNotEquals = {
              "s3:x-amz-server-side-encryption" = var.encryption_type == "SSE-KMS" ? "aws:kms" : "AES256"
            }
          }
        },
        {
          Sid       = "DenyIncorrectKMSKey"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:PutObject"
          Resource  = "${aws_s3_bucket.main.arn}/*"
          Condition = {
            StringNotEquals = {
              "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.encryption_type == "SSE-KMS" ? aws_kms_key.s3[0].arn : ""
            }
          }
        }
      ],
      var.bucket_policy_statements
    )
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# ---------------------------------------------------------------------------
# Access Logging
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_logging" "main" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "access-logs/"
}

# ---------------------------------------------------------------------------
# Lifecycle Policies
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = var.enable_lifecycle_policy ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = var.transition_to_glacier_days
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

# ---------------------------------------------------------------------------
# CORS Configuration
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_cors_configuration" "main" {
  count = length(var.cors_allowed_origins) > 0 ? 1 : 0

  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.cors_allowed_origins
    max_age_seconds = 3600
    expose_headers  = ["ETag"]
  }
}

# ---------------------------------------------------------------------------
# Website Hosting
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_website_configuration" "main" {
  count = var.enable_website_hosting ? 1 : 0

  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = var.website_index_document
  }

  error_document {
    key = var.website_error_document
  }
}

# ---------------------------------------------------------------------------
# Object Lock Configuration
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_object_lock_configuration" "main" {
  count = var.enable_object_lock ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.object_lock_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

# ---------------------------------------------------------------------------
# Cross-Region Replication (Production)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = "${var.project_name}-assets-${var.environment}-replica-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-assets-${var.environment}-replica"
  })

  force_destroy = false
}

resource "aws_s3_bucket_versioning" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = aws_s3_bucket.replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket = aws_s3_bucket.replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type == "SSE-KMS" ? "aws:kms" : "AES256"
      kms_master_key_id = var.encryption_type == "SSE-KMS" ? aws_kms_key.replica[0].arn : null
    }
    bucket_key_enabled = true
  }
}

resource "aws_kms_key" "replica" {
  count    = var.enable_replication && var.encryption_type == "SSE-KMS" ? 1 : 0
  provider = aws.replica

  description             = "KMS key for S3 replica bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_s3_bucket_replication_configuration" "main" {
  count = var.enable_replication ? 1 : 0

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.replica[0].arn

      encryption_configuration {
        replica_kms_key_id = var.encryption_type == "SSE-KMS" ? aws_kms_key.replica[0].arn : null
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = var.encryption_type == "SSE-KMS" ? "Enabled" : "Disabled"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

resource "aws_iam_role" "replication" {
  count = var.enable_replication ? 1 : 0

  name = "${var.project_name}-s3-replication-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "replication" {
  count = var.enable_replication ? 1 : 0

  name = "${var.project_name}-s3-replication-policy"
  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectLegalHold",
          "s3:GetObjectRetention"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = "${aws_s3_bucket.replica[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.encryption_type == "SSE-KMS" ? aws_kms_key.s3[0].arn : "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"                = "s3.${data.aws_region.current.name}.amazonaws.com"
            "kms:EncryptionContext:aws:s3:arn" = aws_s3_bucket.main.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt"
        ]
        Resource = var.encryption_type == "SSE-KMS" ? aws_kms_key.replica[0].arn : "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.replication_destination_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Event Notifications
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "bucket_events" {
  count = var.enable_event_notifications ? 1 : 0

  name = "${var.project_name}-s3-events-${var.environment}"

  tags = local.common_tags
}

resource "aws_s3_bucket_notification" "main" {
  count = var.enable_event_notifications ? 1 : 0

  bucket = aws_s3_bucket.main.id

  topic {
    topic_arn     = aws_sns_topic.bucket_events[0].arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".log"
  }
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
