# ---------------------------------------------------------------------------
# Staging Environment - Terraform Variables
# ---------------------------------------------------------------------------
# Pre-production environment with high availability enabled.
# ---------------------------------------------------------------------------

aws_region = "us-east-1"
environment = "staging"
project_name = "aws-infra"

# VPC Configuration (3 AZs for HA)
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
database_subnet_cidrs = ["10.1.7.0/24", "10.1.8.0/24", "10.1.9.0/24"]

# Compute
instance_type        = "t3.medium"
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

# Enable HTTPS (provide ACM cert or use self-signed)
enable_https = false

# Database (Multi-AZ enabled)
rds_instance_class    = "db.t3.medium"
rds_allocated_storage = 50
multi_az_rds          = true
rds_backup_retention  = 7

# Networking (per-AZ NAT)
enable_nat_gateway = true
single_nat_gateway = false

# Tags
tags = {
  CostCenter = "engineering"
  Owner      = "qa-team"
}
