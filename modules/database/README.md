# Database Module

A production-ready Terraform module for deploying RDS PostgreSQL instances with high availability, encryption, and comprehensive monitoring.

## Features

- **RDS PostgreSQL** with Multi-AZ for high availability
- **Storage encryption** using customer-managed KMS keys
- **Automated backups** with configurable retention
- **Performance Insights** for query-level analysis
- **Enhanced Monitoring** for OS-level metrics
- **CloudWatch Logs** export for PostgreSQL logs
- **Secrets Manager** integration for credential storage
- **Read Replicas** for read-heavy workloads (optional)
- **Custom Parameter Group** with security and performance tuning
- **RDS Event Subscriptions** for operational events
- **CloudWatch Alarms** for CPU, storage, memory, and connections

## Usage

```hcl
module "database" {
  source = "./modules/database"

  environment = "prod"
  project_name = "myapp"
  vpc_id       = module.vpc.vpc_id

  database_subnet_ids  = module.vpc.database_subnet_ids
  private_subnet_cidrs = module.vpc.private_subnet_cidrs
  vpc_cidr_block       = module.vpc.vpc_cidr_block

  instance_class       = "db.t3.medium"
  allocated_storage    = 50
  max_allocated_storage = 500
  database_name        = "app_database"
  master_username      = "dbadmin"

  multi_az                     = true
  backup_retention_period      = 14
  enable_performance_insights  = true
  performance_insights_retention = 31
  enable_enhanced_monitoring   = true
  enable_read_replica          = true

  tags = {
    CostCenter = "engineering"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS Provider | >= 5.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | `string` | n/a | yes |
| project_name | Project name | `string` | `"aws-infra"` | no |
| vpc_id | VPC ID | `string` | n/a | yes |
| database_subnet_ids | Database subnet IDs | `list(string)` | n/a | yes |
| private_subnet_cidrs | Private subnet CIDRs | `list(string)` | n/a | yes |
| vpc_cidr_block | VPC CIDR block | `string` | n/a | yes |
| engine_version | PostgreSQL version | `string` | `"15.4"` | no |
| instance_class | RDS instance class | `string` | `"db.t3.micro"` | no |
| allocated_storage | Initial storage (GB) | `number` | `20` | no |
| max_allocated_storage | Max storage (GB) | `number` | `100` | no |
| database_name | Default database name | `string` | `"app_database"` | no |
| master_username | Master username | `string` | `"dbadmin"` | no |
| master_password | Master password (empty = random) | `string` | `""` | no |
| multi_az | Enable Multi-AZ | `bool` | `true` | no |
| backup_retention_period | Backup retention (days) | `number` | `7` | no |
| enable_performance_insights | Enable Performance Insights | `bool` | `true` | no |
| enable_read_replica | Create read replica | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| rds_endpoint | RDS connection endpoint |
| rds_address | RDS hostname |
| rds_port | RDS port |
| rds_database_name | Default database name |
| rds_instance_class | Instance class |
| rds_multi_az | Multi-AZ enabled |
| rds_storage_encrypted | Encryption enabled |
| security_group_id | RDS security group ID |
| kms_key_arn | KMS key ARN |
| secrets_manager_arn | Secrets Manager ARN |
| read_replica_endpoint | Read replica endpoint |
| sns_topic_arn | SNS topic ARN |

## Security

- Credentials stored in Secrets Manager with automatic rotation support
- SSL/TLS enforcement via parameter group
- Network access restricted to private subnets
- Encryption at rest with KMS and in transit with SSL
- Query logging enabled for audit compliance
