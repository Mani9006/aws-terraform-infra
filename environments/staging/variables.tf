# ---------------------------------------------------------------------------
# Staging Environment - Variables
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for the staging environment."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "staging"
}

variable "project_name" {
  description = "Project name for resource naming."
  type        = string
  default     = "aws-infra"
}

variable "vpc_cidr" {
  description = "VPC CIDR block for staging."
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for staging (3 AZs for HA testing)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for staging."
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for staging."
  type        = list(string)
  default     = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDRs for staging."
  type        = list(string)
  default     = ["10.1.7.0/24", "10.1.8.0/24", "10.1.9.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for staging (medium for realistic testing)."
  type        = string
  default     = "t3.medium"
}

variable "rds_instance_class" {
  description = "RDS instance class for staging."
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage for staging."
  type        = number
  default     = 50
}

variable "asg_min_size" {
  description = "ASG minimum size for staging."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "ASG maximum size for staging."
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity for staging."
  type        = number
  default     = 2
}

variable "enable_https" {
  description = "Enable HTTPS on ALB in staging."
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS in staging."
  type        = string
  default     = ""
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for staging."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for staging."
  type        = bool
  default     = false
}

variable "multi_az_rds" {
  description = "Enable Multi-AZ for RDS in staging."
  type        = bool
  default     = true
}

variable "rds_backup_retention" {
  description = "RDS backup retention for staging."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags for staging environment."
  type        = map(string)
  default     = {}
}
