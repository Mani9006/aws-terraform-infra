# ---------------------------------------------------------------------------
# Production Environment - Variables
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for production (primary)."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name for resource naming."
  type        = string
  default     = "aws-infra"
}

variable "vpc_cidr" {
  description = "VPC CIDR block for production."
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for production (3 AZs minimum)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for production."
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for production."
  type        = list(string)
  default     = ["10.2.4.0/24", "10.2.5.0/24", "10.2.6.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDRs for production."
  type        = list(string)
  default     = ["10.2.7.0/24", "10.2.8.0/24", "10.2.9.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for production."
  type        = string
  default     = "t3.medium"
}

variable "rds_instance_class" {
  description = "RDS instance class for production."
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage for production."
  type        = number
  default     = 100
}

variable "asg_min_size" {
  description = "ASG minimum size for production."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "ASG maximum size for production."
  type        = number
  default     = 10
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity for production."
  type        = number
  default     = 3
}

variable "enable_https" {
  description = "Enable HTTPS on ALB in production (required)."
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS in production (required)."
  type        = string
  default     = ""

  validation {
    condition     = var.acm_certificate_arn != "" || !var.enable_https
    error_message = "ACM certificate ARN is required when HTTPS is enabled in production."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for production (required)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for production (false for HA)."
  type        = bool
  default     = false
}

variable "multi_az_rds" {
  description = "Enable Multi-AZ for RDS in production (required)."
  type        = bool
  default     = true
}

variable "rds_backup_retention" {
  description = "RDS backup retention for production (maximum)."
  type        = number
  default     = 35
}

variable "enable_read_replica" {
  description = "Enable read replica for production."
  type        = bool
  default     = true
}

variable "enable_replication" {
  description = "Enable S3 cross-region replication for production."
  type        = bool
  default     = true
}

variable "replication_destination_region" {
  description = "Destination region for S3 cross-region replication."
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Additional tags for production environment."
  type        = map(string)
  default     = {}
}
