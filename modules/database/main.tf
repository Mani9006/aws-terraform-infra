# ---------------------------------------------------------------------------
# Database Module - Main Configuration
# ---------------------------------------------------------------------------
# Provisions a production-ready RDS PostgreSQL instance with Multi-AZ,
# encryption, backups, Performance Insights, Enhanced Monitoring,
# CloudWatch logs, and Secrets Manager integration.
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

  # Generate a random password if one is not provided
  use_random_password = var.master_password == ""
  master_password     = local.use_random_password ? random_password.master[0].result : var.master_password
}

# ---------------------------------------------------------------------------
# Random Password Generation
# ---------------------------------------------------------------------------

resource "random_password" "master" {
  count = local.use_random_password ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# ---------------------------------------------------------------------------
# KMS Key for RDS Encryption
# ---------------------------------------------------------------------------

resource "aws_kms_key" "rds" {
  count = var.storage_encrypted ? 1 : 0

  description             = "KMS key for RDS storage encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true
  multi_region            = var.environment == "prod"

  tags = local.common_tags
}

resource "aws_kms_alias" "rds" {
  count = var.storage_encrypted ? 1 : 0

  name          = "alias/${var.project_name}-rds-${var.environment}"
  target_key_id = aws_kms_key.rds[0].key_id
}

# ---------------------------------------------------------------------------
# DB Subnet Group
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-${var.environment}"
  description = "Database subnet group for ${var.project_name} ${var.environment}"
  subnet_ids  = var.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-${var.environment}"
  })
}

# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  # PostgreSQL access from private subnets only
  ingress {
    description = "PostgreSQL from private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  # PostgreSQL access from VPC CIDR (for bastion/SSM)
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # No outbound needed for RDS (stateful security group)
  # But explicit deny helps with compliance scanning
  egress {
    description = "Deny all outbound (not needed for RDS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# DB Parameter Group
# ---------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-pg-${var.environment}"
  family      = "postgres15"
  description = "Custom parameter group for ${var.project_name} ${var.environment}"

  # Logging configuration
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = var.environment == "prod" ? "1000" : "100"
    apply_method = "immediate"
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  # Performance tuning
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,auto_explain"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "auto_explain.log_min_duration"
    value = "5000"
    apply_method = "immediate"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
    apply_method = "immediate"
  }

  # Security settings
  parameter {
    name  = "rds.force_ssl"
    value = "1"
    apply_method = "pending-reboot"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring
# ---------------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  name = "${var.project_name}-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---------------------------------------------------------------------------
# RDS Instance
# ---------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}"

  # Engine configuration
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.storage_encrypted ? aws_kms_key.rds[0].arn : null

  # Database configuration
  db_name  = var.database_name
  username = var.master_username
  password = local.master_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.environment == "prod" ? true : var.multi_az
  port                   = 5432

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup and maintenance
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  deletion_protection     = var.environment == "prod" ? true : var.deletion_protection
  skip_final_snapshot     = var.environment == "prod" ? false : var.skip_final_snapshot
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-final-snapshot" : null
  copy_tags_to_snapshot   = var.copy_tags_to_snapshot

  # Version management
  allow_major_version_upgrade = var.allow_major_version_upgrade
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  apply_immediately           = var.apply_immediately

  # Monitoring
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? aws_kms_key.rds[0].arn : null
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention : null

  monitoring_interval = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Logging
  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? var.enabled_cloudwatch_logs_exports : []

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-${var.environment}"
  })

  depends_on = [aws_db_subnet_group.main, aws_security_group.rds]

  lifecycle {
    prevent_destroy = var.environment == "prod"
    ignore_changes  = [password]
  }
}

# ---------------------------------------------------------------------------
# Read Replica (Optional)
# ---------------------------------------------------------------------------

resource "aws_db_instance" "replica" {
  count = var.enable_read_replica ? 1 : 0

  identifier = "${var.project_name}-${var.environment}-replica"

  replicate_source_db  = aws_db_instance.main.arn
  instance_class       = var.read_replica_instance_class
  storage_encrypted    = var.storage_encrypted
  kms_key_id           = var.storage_encrypted ? aws_kms_key.rds[0].arn : null
  publicly_accessible  = false
  multi_az             = false

  vpc_security_group_ids = [aws_security_group.rds.id]

  # Read replicas need their own parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Monitoring
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? aws_kms_key.rds[0].arn : null
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention : null

  monitoring_interval = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Logging
  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? var.enabled_cloudwatch_logs_exports : []

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  skip_final_snapshot = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-replica-${var.environment}"
  })

  depends_on = [aws_db_instance.main]
}

# ---------------------------------------------------------------------------
# Secrets Manager - Store Database Credentials
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/${var.environment}/database/credentials"
  description             = "Database credentials for ${var.project_name} ${var.environment}"
  kms_key_id              = aws_kms_key.rds[0].arn
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = local.master_password
    engine   = "postgresql"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.database_name
    jdbc_url = "jdbc:postgresql://${aws_db_instance.main.address}:5432/${var.database_name}"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Log Groups
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "postgresql" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/rds/instance/${var.project_name}-${var.environment}/postgresql"
  retention_in_days = var.cloudwatch_logs_retention
  kms_key_id        = aws_kms_key.rds[0].arn

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-rds-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization exceeds 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "storage_low" {
  alarm_name          = "${var.project_name}-rds-storage-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB in bytes
  alarm_description   = "RDS free storage space below 5 GB"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_low" {
  alarm_name          = "${var.project_name}-rds-memory-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 268435456 # 256 MB in bytes
  alarm_description   = "RDS freeable memory below 256 MB"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "connections_high" {
  alarm_name          = "${var.project_name}-rds-connections-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS database connections exceed 80"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SNS Topic for RDS Alarms
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-rds-alarms-${var.environment}"

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# RDS Event Subscription
# ---------------------------------------------------------------------------

resource "aws_db_event_subscription" "main" {
  name      = "${var.project_name}-rds-events-${var.environment}"
  sns_topic = aws_sns_topic.alarms.arn

  source_type = "db-instance"
  source_ids  = [aws_db_instance.main.identifier]

  event_categories = [
    "availability",
    "deletion",
    "failover",
    "failure",
    "low storage",
    "maintenance",
    "notification",
    "recovery",
    "restoration"
  ]

  tags = local.common_tags
}
