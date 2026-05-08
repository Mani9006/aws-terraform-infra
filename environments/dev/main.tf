# ---------------------------------------------------------------------------
# Dev Environment - Main Configuration
# ---------------------------------------------------------------------------
# Orchestrates all modules for the development environment with cost-
# optimized settings. Single NAT gateway and no Multi-AZ for RDS.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# AWS Provider
# ---------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Local Values
# ---------------------------------------------------------------------------

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# VPC Module
# ---------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  environment = var.environment
  project_name = var.project_name
  vpc_cidr    = var.vpc_cidr

  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_vpc_flow_logs = true
  flow_logs_retention_days = 7
  enable_network_acl   = true

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Storage Module
# ---------------------------------------------------------------------------

module "storage" {
  source = "../../modules/storage"

  environment = var.environment
  project_name = var.project_name

  enable_versioning           = true
  enable_encryption           = true
  encryption_type             = "SSE-KMS"
  enable_access_logging       = true
  enable_lifecycle_policy     = true
  transition_to_ia_days       = 30
  transition_to_glacier_days  = 90
  noncurrent_version_expiration_days = 30
  block_public_access         = true
  force_destroy               = true

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Database Module
# ---------------------------------------------------------------------------

module "database" {
  source = "../../modules/database"

  environment = var.environment
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id

  database_subnet_ids  = module.vpc.database_subnet_ids
  private_subnet_cidrs = module.vpc.private_subnet_cidrs
  vpc_cidr_block       = module.vpc.vpc_cidr_block

  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  max_allocated_storage = 100
  multi_az             = var.multi_az_rds
  backup_retention_period = var.rds_backup_retention

  enable_performance_insights = false
  enable_enhanced_monitoring  = false
  enable_cloudwatch_logs      = true
  skip_final_snapshot         = true

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Compute Module
# ---------------------------------------------------------------------------

module "compute" {
  source = "../../modules/compute"

  environment = var.environment
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block

  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_type        = var.instance_type
  min_size             = var.asg_min_size
  max_size             = var.asg_max_size
  desired_capacity     = var.asg_desired_capacity
  enable_https         = false
  health_check_path    = "/health"
  enable_monitoring    = true
  root_volume_size     = 20
  root_volume_type     = "gp3"
  enable_volume_encryption = true

  # Use the storage bucket for ALB access logs
  alb_access_logs_enabled   = true
  alb_access_logs_s3_bucket = module.storage.logging_bucket_id

  tags = var.tags

  depends_on = [module.vpc, module.storage]
}
