# VPC Module

A production-ready Terraform module for creating AWS VPC infrastructure with public, private, and database subnets across multiple availability zones.

## Features

- **Multi-AZ VPC** with public, private, and database subnet tiers
- **NAT Gateways** with per-AZ or shared configuration
- **VPC Flow Logs** with CloudWatch integration and KMS encryption
- **Network ACLs** for defense-in-depth subnet security
- **VPC Endpoints** for S3, SSM, and CloudWatch (private connectivity)
- **Internet Gateway** with public route tables
- **KMS Encryption** for log data protection

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  environment = "prod"
  project_name = "myapp"
  vpc_cidr = "10.0.0.0/16"

  availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  database_subnet_cidrs = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false  # Per-AZ NAT for production
  enable_vpc_flow_logs = true
  flow_logs_retention_days = 90

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
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| project_name | Project name for resource naming | `string` | `"aws-infra"` | no |
| vpc_cidr | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| availability_zones | List of AZs for subnet placement | `list(string)` | n/a | yes |
| public_subnet_cidrs | CIDR blocks for public subnets | `list(string)` | n/a | yes |
| private_subnet_cidrs | CIDR blocks for private subnets | `list(string)` | n/a | yes |
| database_subnet_cidrs | CIDR blocks for database subnets | `list(string)` | n/a | yes |
| enable_nat_gateway | Enable NAT gateways | `bool` | `true` | no |
| single_nat_gateway | Use single NAT gateway | `bool` | `false` | no |
| enable_vpc_flow_logs | Enable VPC flow logs | `bool` | `true` | no |
| flow_logs_retention_days | Flow logs retention period | `number` | `30` | no |
| enable_network_acl | Enable network ACLs | `bool` | `true` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the created VPC |
| vpc_cidr_block | The CIDR block of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| database_subnet_ids | List of database subnet IDs |
| nat_gateway_ids | List of NAT gateway IDs |
| nat_gateway_public_ips | List of NAT gateway public IPs |
| internet_gateway_id | Internet gateway ID |
| vpc_endpoint_s3_id | S3 VPC endpoint ID |

## Security

- Database subnets have restrictive NACLs allowing only PostgreSQL traffic
- VPC flow logs capture all network traffic for audit
- KMS encryption protects log data at rest
- VPC endpoints keep AWS service traffic within the AWS network
