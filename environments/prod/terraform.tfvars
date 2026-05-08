# ---------------------------------------------------------------------------
# Production Environment - Terraform Variables
# ---------------------------------------------------------------------------
# Full high-availability configuration. This is the production environment.
# Changes must go through the change management process.
# ---------------------------------------------------------------------------

aws_region = "us-east-1"
environment = "prod"
project_name = "aws-infra"

# VPC Configuration (3 AZs for maximum availability)
vpc_cidr             = "10.2.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs = ["10.2.4.0/24", "10.2.5.0/24", "10.2.6.0/24"]
database_subnet_cidrs = ["10.2.7.0/24", "10.2.8.0/24", "10.2.9.0/24"]

# Compute (production grade)
instance_type        = "t3.medium"
asg_min_size         = 2
asg_max_size         = 10
asg_desired_capacity = 3

# HTTPS (required in production)
enable_https = true
# Replace with your ACM certificate ARN
# acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/YOUR-CERT-ARN"

# Database (Multi-AZ with max retention)
rds_instance_class    = "db.t3.medium"
rds_allocated_storage = 100
multi_az_rds          = true
rds_backup_retention  = 35
enable_read_replica   = true

# Networking (per-AZ NAT for HA)
enable_nat_gateway = true
single_nat_gateway = false

# S3 (cross-region replication for DR)
enable_replication             = true
replication_destination_region = "us-west-2"

# Tags
tags = {
  CostCenter   = "engineering"
  Owner        = "platform-team"
  Criticality  = "high"
  DataClass    = "confidential"
  Compliance   = "soc2"
}
