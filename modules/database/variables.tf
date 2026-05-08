# ---------------------------------------------------------------------------
# Database Module - Variables
# ---------------------------------------------------------------------------
# Variables for provisioning RDS PostgreSQL instances with high availability,
# encryption, backup, and monitoring configurations.
# ---------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging."
  type        = string
  default     = "aws-infra"
}

variable "vpc_id" {
  description = "ID of the VPC where the RDS instance will be deployed."
  type        = string
}

variable "database_subnet_ids" {
  description = "List of database subnet IDs for the RDS subnet group."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets for security group ingress rules."
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC for security group rules."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version. Only supported versions allowed."
  type        = string
  default     = "15.4"

  validation {
    condition     = can(regex("^15\\.[0-9]+$", var.engine_version)) || can(regex("^16\\.[0-9]+$", var.engine_version))
    error_message = "Only PostgreSQL 15.x and 16.x are supported."
  }
}

variable "instance_class" {
  description = "RDS instance class. Must be db.t3 or higher for production workloads."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.t3\\.|^db\\.t4g\\.|^db\\.m6\\.|^db\\.r6\\.|^db\\.m7\\.|^db\\.r7\\.", var.instance_class))
    error_message = "Instance class must be a valid RDS instance type (t3, t4g, m6, r6, m7, r7 family)."
  }
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB. Must be >= allocated_storage."
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "Max allocated storage must be greater than or equal to allocated storage."
  }
}

variable "storage_type" {
  description = "Storage type for the RDS instance."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "Storage type must be one of: gp2, gp3, io1, io2."
  }
}

variable "database_name" {
  description = "Name of the default database to create. Must follow PostgreSQL naming rules."
  type        = string
  default     = "app_database"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.database_name))
    error_message = "Database name must start with a letter or underscore and contain only alphanumeric characters."
  }
}

variable "master_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.master_username))
    error_message = "Master username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "master_password" {
  description = "Master password for the RDS instance. If empty, a random password is generated and stored in Secrets Manager."
  type        = string
  default     = ""
  sensitive   = true
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability. Always true in production."
  type        = bool
  default     = true
}

variable "publicly_accessible" {
  description = "Make the RDS instance publicly accessible. Must be false for security."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "backup_window" {
  description = "Preferred backup window in UTC (hh:mm-hh:mm)."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window in UTC (ddd:hh:mm-ddd:hh:mm)."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection on the RDS instance."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion. Should be false in production."
  type        = bool
  default     = false
}

variable "enable_performance_insights" {
  description = "Enable RDS Performance Insights for query analysis."
  type        = bool
  default     = true
}

variable "performance_insights_retention" {
  description = "Performance Insights retention period in days."
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372, 403, 434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731], var.performance_insights_retention)
    error_message = "Performance Insights retention must be 7, 31, or a multiple of 31 up to 731 days."
  }
}

variable "enable_enhanced_monitoring" {
  description = "Enable Enhanced Monitoring for OS-level metrics."
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs export for PostgreSQL."
  type        = bool
  default     = true
}

variable "cloudwatch_logs_retention" {
  description = "CloudWatch logs retention in days."
  type        = number
  default     = 30
}

variable "allow_major_version_upgrade" {
  description = "Allow major version upgrades during maintenance windows."
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Automatically apply minor version upgrades during maintenance windows."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately instead of during maintenance window."
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of PostgreSQL log types to export to CloudWatch."
  type        = list(string)
  default     = ["postgresql", "upgrade"]

  validation {
    condition     = alltrue([for log in var.enabled_cloudwatch_logs_exports : contains(["postgresql", "upgrade", "agent"], log)])
    error_message = "Valid log types: postgresql, upgrade, agent."
  }
}

variable "tags" {
  description = "Additional tags to apply to all database resources."
  type        = map(string)
  default     = {}
}

variable "enable_read_replica" {
  description = "Create a read replica for read-heavy workloads."
  type        = bool
  default     = false
}

variable "read_replica_instance_class" {
  description = "Instance class for the read replica."
  type        = string
  default     = "db.t3.micro"
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to automated and manual snapshots."
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Enable storage encryption using KMS."
  type        = bool
  default     = true
}
