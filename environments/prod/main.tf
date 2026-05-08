# ---------------------------------------------------------------------------
# Production Environment - Main Configuration
# ---------------------------------------------------------------------------
# Full high-availability configuration with Multi-AZ RDS, per-AZ NAT
# gateways, S3 cross-region replication, read replicas, deletion protection,
# and comprehensive monitoring.
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
# AWS Provider (Primary Region)
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
# AWS Provider (Replica Region for S3 CRR)
# ---------------------------------------------------------------------------

provider "aws" {
  alias  = "replica"
  region = var.replication_destination_region

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
  flow_logs_retention_days = 90
  enable_network_acl   = true

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Storage Module
# ---------------------------------------------------------------------------

module "storage" {
  source = "../../modules/storage"

  providers = {
    aws.replica = aws.replica
  }

  environment = var.environment
  project_name = var.project_name

  enable_versioning            = true
  enable_encryption            = true
  encryption_type              = "SSE-KMS"
  enable_access_logging        = true
  enable_lifecycle_policy      = true
  transition_to_ia_days        = 30
  transition_to_glacier_days   = 90
  noncurrent_version_expiration_days = 180
  block_public_access          = true
  force_destroy                = false
  enable_replication           = var.enable_replication
  replication_destination_region = var.replication_destination_region
  enable_object_lock           = true
  object_lock_retention_days   = 30
  enable_event_notifications   = true

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

  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  max_allocated_storage  = 1000
  multi_az               = var.multi_az_rds
  backup_retention_period = var.rds_backup_retention

  enable_performance_insights    = true
  performance_insights_retention = 31
  enable_enhanced_monitoring     = true
  monitoring_interval            = 60
  enable_cloudwatch_logs         = true
  cloudwatch_logs_retention      = 90
  deletion_protection            = true
  skip_final_snapshot            = false
  enable_read_replica            = var.enable_read_replica
  copy_tags_to_snapshot          = true

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

  instance_type              = var.instance_type
  min_size                   = var.asg_min_size
  max_size                   = var.asg_max_size
  desired_capacity           = var.asg_desired_capacity
  enable_https               = var.enable_https
  acm_certificate_arn        = var.acm_certificate_arn
  health_check_path          = "/health"
  enable_monitoring          = true
  enable_deletion_protection = true
  enable_scaling_policies    = true
  root_volume_size           = 50
  root_volume_type           = "gp3"
  enable_volume_encryption   = true
  enable_termination_protection = true
  health_check_grace_period  = 300
  instance_warmup            = 180

  alb_access_logs_enabled   = true
  alb_access_logs_s3_bucket = module.storage.logging_bucket_id
  alb_idle_timeout          = 60

  tags = var.tags

  depends_on = [module.vpc, module.storage]
}
