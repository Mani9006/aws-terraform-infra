# ---------------------------------------------------------------------------
# VPC Module - Variables
# ---------------------------------------------------------------------------
# This module creates a production-ready VPC with public and private subnets
# across multiple availability zones. Supports VPC flow logs, NAT gateways,
# and network ACLs for defense-in-depth security.
# ---------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod). Used for resource naming and tagging."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging consistency."
  type        = string
  default     = "aws-infra"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a valid RFC1918 private range."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of AWS availability zones to deploy subnets into. Minimum 2 for high availability."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ. These host the load balancers and bastion hosts."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of public subnet CIDRs must match the number of availability zones."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ. These host application instances and databases."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of private subnet CIDRs must match the number of availability zones."
  }
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets, one per AZ. These are isolated subnets for RDS deployments."
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of database subnet CIDRs must match the number of availability zones."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateways to allow outbound internet access from private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway shared across all AZs. Set to false in production for per-AZ NAT."
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs for network traffic analysis and security auditing."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC flow logs in CloudWatch."
  type        = number
  default     = 30

  validation {
    condition     = var.flow_logs_retention_days >= 1 && var.flow_logs_retention_days <= 365
    error_message = "Flow logs retention must be between 1 and 365 days."
  }
}

variable "enable_network_acl" {
  description = "Enable custom network ACLs for additional subnet-level security controls."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all VPC resources."
  type        = map(string)
  default     = {}
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC. Required for EC2 instances to receive public DNS names."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS resolution support in the VPC."
  type        = bool
  default     = true
}
