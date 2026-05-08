# ---------------------------------------------------------------------------
# Storage Module - Outputs
# ---------------------------------------------------------------------------
# Exposes bucket identifiers, ARNs, and connection details.
# ---------------------------------------------------------------------------

output "bucket_id" {
  description = "ID (name) of the main S3 bucket."
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of the main S3 bucket."
  value       = aws_s3_bucket.main.arn
}

output "bucket_name" {
  description = "Name of the main S3 bucket."
  value       = aws_s3_bucket.main.bucket
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket."
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket."
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_versioning_status" {
  description = "Versioning status of the bucket."
  value       = aws_s3_bucket_versioning.main.versioning_configuration[0].status
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for bucket encryption."
  value       = var.enable_encryption && var.encryption_type == "SSE-KMS" ? aws_kms_key.s3[0].arn : null
}

output "kms_key_id" {
  description = "ID of the KMS key used for bucket encryption."
  value       = var.enable_encryption && var.encryption_type == "SSE-KMS" ? aws_kms_key.s3[0].key_id : null
}

output "logging_bucket_id" {
  description = "ID of the logging bucket. Null if access logging is disabled."
  value       = var.enable_access_logging ? aws_s3_bucket.logs[0].id : null
}

output "logging_bucket_arn" {
  description = "ARN of the logging bucket."
  value       = var.enable_access_logging ? aws_s3_bucket.logs[0].arn : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for bucket events. Null if notifications disabled."
  value       = var.enable_event_notifications ? aws_sns_topic.bucket_events[0].arn : null
}

output "replica_bucket_arn" {
  description = "ARN of the replica bucket. Null if replication is disabled."
  value       = var.enable_replication ? aws_s3_bucket.replica[0].arn : null
}

output "website_endpoint" {
  description = "Website endpoint URL. Null if website hosting is disabled."
  value       = var.enable_website_hosting ? aws_s3_bucket_website_configuration.main[0].website_endpoint : null
}

output "object_lock_enabled" {
  description = "Whether Object Lock is enabled."
  value       = aws_s3_bucket.main.object_lock_enabled
}

output "encryption_type" {
  description = "Encryption type applied to the bucket."
  value       = var.encryption_type
}
