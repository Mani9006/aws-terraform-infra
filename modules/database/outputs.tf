# ---------------------------------------------------------------------------
# Database Module - Outputs
# ---------------------------------------------------------------------------
# Exposes database connection details and resource identifiers.
# Password is never output directly - use Secrets Manager.
# ---------------------------------------------------------------------------

output "rds_instance_id" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.main.id
}

output "rds_instance_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.main.arn
}

output "rds_instance_identifier" {
  description = "Unique identifier of the RDS instance."
  value       = aws_db_instance.main.identifier
}

output "rds_endpoint" {
  description = "Connection endpoint of the RDS instance. Does not include port."
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "Hostname of the RDS instance."
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "Port number the RDS instance listens on."
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "Name of the default database."
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "Master username for the RDS instance."
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "rds_instance_class" {
  description = "Instance class of the RDS instance."
  value       = aws_db_instance.main.instance_class
}

output "rds_engine_version" {
  description = "Engine version of the RDS instance."
  value       = aws_db_instance.main.engine_version_actual
}

output "rds_multi_az" {
  description = "Whether Multi-AZ is enabled."
  value       = aws_db_instance.main.multi_az
}

output "rds_storage_encrypted" {
  description = "Whether storage encryption is enabled."
  value       = aws_db_instance.main.storage_encrypted
}

output "security_group_id" {
  description = "ID of the RDS security group."
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.main.name
}

output "parameter_group_name" {
  description = "Name of the DB parameter group."
  value       = aws_db_parameter_group.main.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for RDS encryption."
  value       = aws_kms_key.rds[0].arn
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret containing credentials."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secrets_manager_name" {
  description = "Name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "read_replica_endpoint" {
  description = "Connection endpoint of the read replica. Null if not enabled."
  value       = var.enable_read_replica ? aws_db_instance.replica[0].endpoint : null
}

output "read_replica_arn" {
  description = "ARN of the read replica. Null if not enabled."
  value       = var.enable_read_replica ? aws_db_instance.replica[0].arn : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for RDS alarms."
  value       = aws_sns_topic.alarms.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for PostgreSQL logs."
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.postgresql[0].name : null
}
