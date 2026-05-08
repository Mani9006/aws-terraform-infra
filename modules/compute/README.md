# Compute Module

A production-ready Terraform module for deploying auto-scaled EC2 application servers behind an Application Load Balancer on AWS.

## Features

- **Auto Scaling Group** with launch templates and instance refresh
- **Application Load Balancer** with HTTP/HTTPS listeners and health checks
- **Target Tracking Scaling** based on CPU utilization
- **Security Groups** following least privilege principles
- **EBS Encryption** with customer-managed KMS keys
- **IAM Instance Profile** with SSM Session Manager, CloudWatch, S3, ECR, and Secrets Manager access
- **CloudWatch Alarms** for high CPU, low CPU, and instance health
- **IMDSv2 enforcement** for metadata service security
- **User data support** for custom instance initialization

## Usage

```hcl
module "compute" {
  source = "./modules/compute"

  environment = "prod"
  project_name = "myapp"
  vpc_id       = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block

  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_type = "t3.medium"
  min_size      = 2
  max_size      = 10
  desired_capacity = 4

  enable_https          = true
  acm_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/..."
  health_check_path     = "/api/health"

  user_data = templatefile("${path.module}/user-data.sh", {
    environment = "prod"
    db_host     = module.database.rds_endpoint
  })

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
| public_subnet_ids | Public subnet IDs | `list(string)` | n/a | yes |
| private_subnet_ids | Private subnet IDs | `list(string)` | n/a | yes |
| vpc_cidr_block | VPC CIDR block | `string` | n/a | yes |
| instance_type | EC2 instance type | `string` | `"t3.micro"` | no |
| ami_id | AMI ID (empty = latest AL2023) | `string` | `""` | no |
| min_size | ASG minimum size | `number` | `2` | no |
| max_size | ASG maximum size | `number` | `6` | no |
| desired_capacity | ASG desired capacity | `number` | `2` | no |
| enable_scaling_policies | Enable scaling policies | `bool` | `true` | no |
| cpu_target_value | Target CPU % | `number` | `60` | no |
| enable_load_balancer | Enable ALB | `bool` | `true` | no |
| enable_https | Enable HTTPS | `bool` | `false` | no |
| acm_certificate_arn | ACM certificate ARN | `string` | `""` | no |
| health_check_path | Health check path | `string` | `"/health"` | no |
| root_volume_size | Root volume size (GB) | `number` | `20` | no |
| key_name | EC2 key pair name | `string` | `""` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| launch_template_id | Launch template ID |
| autoscaling_group_name | ASG name |
| alb_dns_name | ALB DNS name |
| alb_arn | ALB ARN |
| target_group_arn | Target group ARN |
| security_group_ec2_id | EC2 security group ID |
| iam_role_arn | IAM role ARN |
| sns_topic_arn | SNS topic ARN for alarms |
| kms_key_arn_ebs | EBS KMS key ARN |
