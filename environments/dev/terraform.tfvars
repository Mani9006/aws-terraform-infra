# ---------------------------------------------------------------------------
# Dev Environment - Terraform Variables
# ---------------------------------------------------------------------------
# Cost-optimized configuration for development and testing.
# ---------------------------------------------------------------------------

aws_region = "us-east-1"
environment = "dev"
project_name = "aws-infra"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
database_subnet_cidrs = ["10.0.5.0/24", "10.0.6.0/24"]

# Compute (cost-optimized)
instance_type        = "t3.micro"
asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 1

# Database (cost-optimized, single AZ)
rds_instance_class    = "db.t3.micro"
rds_allocated_storage = 20
multi_az_rds          = false
rds_backup_retention  = 1

# Networking (single NAT for cost savings)
enable_nat_gateway = true
single_nat_gateway = true

# Tags
tags = {
  CostCenter  = "engineering"
  Owner       = "dev-team"
  AutoShutdown = "true"
}
