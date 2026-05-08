# ---------------------------------------------------------------------------
# Dev Environment - Variables
# ---------------------------------------------------------------------------
# Dev-specific variable declarations and defaults.
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name - always dev for this configuration."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming."
  type        = string
  default     = "aws-infra"
}

variable "vpc_cidr" {
  description = "VPC CIDR block for dev."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for dev deployment."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for dev."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for dev."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDRs for dev."
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for dev (cost-optimized)."
  type        = string
  default     = "t3.micro"
}

variable "rds_instance_class" {
  description = "RDS instance class for dev (cost-optimized)."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage for dev."
  type        = number
  default     = 20
}

variable "asg_min_size" {
  description = "ASG minimum size for dev."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "ASG maximum size for dev."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity for dev."
  type        = number
  default     = 1
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for dev (can be disabled for cost savings)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for dev to reduce costs."
  type        = bool
  default     = true
}

variable "multi_az_rds" {
  description = "Enable Multi-AZ for RDS in dev."
  type        = bool
  default     = false
}

variable "rds_backup_retention" {
  description = "RDS backup retention for dev."
  type        = number
  default     = 1
}

variable "tags" {
  description = "Additional tags for dev environment."
  type        = map(string)
  default     = {}
}
