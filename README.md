# AWS Infrastructure as Code with Terraform

> A production-grade, modular Terraform project for deploying a secure, scalable, and highly available AWS infrastructure stack.

[![Terraform](https://img.shields.io/badge/terraform-%3E%3D%201.5.0-blue.svg)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/aws%20provider-%3E%3D%205.0.0-orange.svg)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## Table of Contents

- [Architecture Diagram](#architecture-diagram)
- [Project Structure](#project-structure)
- [Modules](#modules)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Workflow](#deployment-workflow)
- [Module Documentation](#module-documentation)
- [State Management](#state-management)
- [Security](#security)
- [Cost Estimates](#cost-estimates)
- [Monitoring](#monitoring)
- [Security Considerations](#security-considerations)
- [Future Improvements](#future-improvements)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Architecture Diagram

```
                                 +------------------+
                                 |    Route 53      |
                                 | (DNS/Health)     |
                                 +--------+---------+
                                          |
                    +---------------------v---------------------+
                    |         Application Load Balancer         |
                    |        (Public Subnets - 3 AZs)           |
                    |     HTTP:80     HTTPS:443 (TLS 1.3)     |
                    +---------------------+---------------------+
                                          |
                          +---------------v---------------+
                          |       Target Group            |
                          |    Health Check: /health      |
                          +---------------+---------------+
                                          |
                    +---------------------v---------------------+
                    |         Auto Scaling Group                |
                    |         (Private Subnets - 3 AZs)         |
                    |  +--------+ +--------+ +--------+        |
                    |  | EC2    | | EC2    | | EC2    |        |
                    |  | t3.med | | t3.med | | t3.med |        |
                    |  | AZ 1a  | | AZ 1b  | | AZ 1c  |        |
                    |  +--------+ +--------+ +--------+        |
                    |    min:2    desired:3    max:10           |
                    +---------------------+---------------------+
                                          |
                    +---------------------v---------------------+
                    |       Amazon RDS PostgreSQL               |
                    |       (Database Subnets - 3 AZs)          |
                    |  +----------+        +----------+        |
                    |  | Primary  |<------>| Standby  |        |
                    |  | (AZ 1a)  |  sync  | (AZ 1b)  |        |
                    |  +----------+        +----------+        |
                    |       [Read Replica - Optional]          |
                    +---------------------+---------------------+
                                          |
                    +---------------------v---------------------+
                    |         Amazon S3                           |
                    |   Encrypted Assets + Access Logs          |
                    |   [Cross-Region Replication: us-west-2]   |
                    +-------------------------------------------+

    +---------------------- VPC 10.x.0.0/16 ---------------------+
    |  Flow Logs | NACLs | IGW | NAT GW | VPC Endpoints (S3/SSM)  |
    +--------------------------------------------------------------+
```

**Full architecture documentation:** [docs/architecture.md](docs/architecture.md)

---

## Project Structure

```
project_12_aws_infrastructure/
|___ modules/
|   |___ vpc/             # VPC, subnets, NAT, flow logs, NACLs
|   |___ compute/         # EC2, ASG, ALB, IAM, CloudWatch alarms
|   |___ database/        # RDS PostgreSQL, backups, monitoring
|   |___ storage/         # S3 buckets, encryption, lifecycle
|
|___ environments/
|   |___ dev/             # Cost-optimized development
|   |___ staging/         # Pre-production with HA
|   |___ prod/            # Full production with DR
|
|___ scripts/
|   |___ init-backend.sh  # Initialize remote state infrastructure
|   |___ plan.sh          # Run terraform plan with validation
|   |___ apply.sh         # Run terraform apply with safety checks
|   |___ destroy.sh       # Destroy with multi-level confirmation
|
|___ policies/
|   |___ iam-policy.json  # Least-privilege IAM policy
|
|___ docs/
|   |___ architecture.md  # Detailed architecture documentation
|
|___ tests/
|   |___ validate.sh      # Terraform validation suite
|   |___ checkov-config.yml # Security scanning configuration
|
|___ .terraformignore     # Files to exclude from Terraform
|___ .gitignore           # Files to exclude from Git
|___ LICENSE              # MIT License
|___ README.md            # This file
```

---

## Modules

| Module | Purpose | Resources |
|--------|---------|-----------|
| **VPC** | Network foundation | VPC, 9 subnets (3 tiers x 3 AZs), IGW, NAT GW, route tables, flow logs, NACLs, VPC endpoints |
| **Compute** | Application tier | Launch template, ASG, ALB, target group, IAM role/instance profile, CloudWatch alarms |
| **Database** | Data tier | RDS PostgreSQL, DB subnet group, parameter group, Secrets Manager, read replica, event subscriptions |
| **Storage** | Object storage | S3 bucket, KMS encryption, versioning, lifecycle policies, cross-region replication, access logging |

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.5.0 | Infrastructure provisioning |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | >= 2.0 | AWS authentication |
| [Checkov](https://www.checkov.io/) | >= 2.0 | Security scanning (optional) |

### AWS Setup

1. **Install AWS CLI** and configure credentials:
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, region (us-east-1), and output format
   ```

2. **Verify authentication**:
   ```bash
   aws sts get-caller-identity
   ```

3. **IAM Permissions**: Ensure your IAM user/role has permissions defined in [`policies/iam-policy.json`](policies/iam-policy.json).

---

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd project_12_aws_infrastructure
```

### 2. Initialize the Backend

Run the initialization script to create the S3 bucket and DynamoDB table for remote state:

```bash
# Initialize backend for dev environment
./scripts/init-backend.sh dev

# (Optional) Initialize staging and production backends
./scripts/init-backend.sh staging
./scripts/init-backend.sh prod
```

### 3. Deploy the Development Environment

```bash
cd environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars -auto-approve
```

### 4. Verify Deployment

```bash
# View outputs
terraform output

# Verify VPC
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"

# Verify ALB
aws elbv2 describe-load-balancers --names "aws-infra-alb-dev"

# Verify RDS
aws rds describe-db-instances --db-instance-identifier "aws-infra-dev"
```

---

## Deployment Workflow

### Environment Promotion Pipeline

```
Local Dev  -->  PR Review  -->  Staging Deploy  -->  QA Validation  -->  Prod Deploy
     |               |                |                     |                 |
   plan.sh       validate.sh      plan.sh              plan.sh          plan.sh
   apply.sh      (CI/CD)          apply.sh             apply.sh         apply.sh
                                                      manual gate
```

### Per-Environment Workflow

#### Development
```bash
# Plan changes
./scripts/plan.sh dev

# Apply (auto-approved)
./scripts/apply.sh dev

# Destroy when done
./scripts/destroy.sh dev
```

#### Staging
```bash
# Plan with review
./scripts/plan.sh staging

# Apply requires confirmation
./scripts/apply.sh staging

# Or use a saved plan file
./scripts/apply.sh staging tfplan-staging-20240101-120000
```

#### Production
```bash
# Always create a plan file first
./scripts/plan.sh prod

# Apply requires plan file + manual confirmation
./scripts/apply.sh prod tfplan-prod-20240101-120000
# You will be prompted to type 'deploy-to-production' to confirm
```

### Validation

Run the validation suite before any deployment:

```bash
# Validate all environments and modules
./tests/validate.sh

# Validate specific environment
./tests/validate.sh dev
```

---

## Module Documentation

### VPC Module

**Location:** [`modules/vpc/`](modules/vpc/)

Creates a complete VPC with three subnet tiers (public, private, database) across multiple availability zones.

**Key Features:**
- Multi-AZ VPC with 9 subnets (3 tiers x 3 AZs in production)
- NAT Gateways (single for dev, per-AZ for staging/prod)
- VPC Flow Logs with CloudWatch integration and KMS encryption
- Network ACLs for defense-in-depth
- VPC Endpoints (S3 Gateway, SSM Interface, CloudWatch Logs)

**Usage:**
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
  single_nat_gateway   = false
  enable_vpc_flow_logs = true
}
```

**Outputs:** `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `database_subnet_ids`, `nat_gateway_ids`

---

### Compute Module

**Location:** [`modules/compute/`](modules/compute/)

Provisions auto-scaled EC2 instances behind an Application Load Balancer.

**Key Features:**
- Launch templates with IMDSv2 enforcement
- Auto Scaling Group with target tracking (CPU)
- Application Load Balancer with HTTP/HTTPS
- IAM instance profile with SSM Session Manager
- EBS encryption with customer-managed KMS
- CloudWatch alarms for CPU and instance health

**Usage:**
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
  desired_capacity = 3

  enable_https     = true
  acm_certificate_arn = "arn:aws:acm:..."
}
```

**Outputs:** `alb_dns_name`, `autoscaling_group_name`, `target_group_arn`, `security_group_ec2_id`

---

### Database Module

**Location:** [`modules/database/`](modules/database/)

Deploys RDS PostgreSQL with high availability, encryption, and comprehensive monitoring.

**Key Features:**
- Multi-AZ PostgreSQL with automated backups
- Storage autoscaling and encryption
- Performance Insights and Enhanced Monitoring
- Secrets Manager for credential storage
- CloudWatch alarms for CPU, storage, memory, connections
- Custom parameter group with security tuning
- Optional read replica

**Usage:**
```hcl
module "database" {
  source = "./modules/database"

  environment = "prod"
  project_name = "myapp"
  vpc_id       = module.vpc.vpc_id

  database_subnet_ids  = module.vpc.database_subnet_ids
  private_subnet_cidrs = module.vpc.private_subnet_cidrs
  vpc_cidr_block       = module.vpc.vpc_cidr_block

  instance_class        = "db.t3.medium"
  allocated_storage     = 100
  multi_az              = true
  backup_retention_period = 35
  enable_read_replica   = true
}
```

**Outputs:** `rds_endpoint`, `rds_address`, `secrets_manager_arn`, `kms_key_arn`

---

### Storage Module

**Location:** [`modules/storage/`](modules/storage/)

Creates encrypted S3 buckets with lifecycle policies and cross-region replication.

**Key Features:**
- SSE-KMS encryption with customer-managed keys
- Versioning and lifecycle policies
- Cross-region replication for disaster recovery
- Access logging to separate bucket
- Object Lock for compliance
- Block all public access
- Deny unencrypted uploads

**Usage:**
```hcl
module "storage" {
  source = "./modules/storage"

  environment = "prod"
  project_name = "myapp"

  enable_versioning      = true
  enable_encryption      = true
  enable_replication     = true
  replication_destination_region = "us-west-2"
  enable_object_lock     = true
}
```

**Outputs:** `bucket_id`, `bucket_arn`, `kms_key_arn`, `logging_bucket_id`

---

## State Management

### Remote State Architecture

```
+-------------------------------------------------+
|              Terraform State                      |
|                                                   |
|  +------------------+  +----------------------+  |
|  | S3 Bucket        |  | DynamoDB Table       |  |
|  | - Versioning     |  | - State Locking      |  |
|  | - KMS Encryption |  | - Pay-per-request    |  |
|  | - Access Logging |  | - Point-in-time      |  |
|  +------------------+  +----------------------+  |
+-------------------------------------------------+
```

### Per-Environment Isolation

| Environment | S3 Bucket | DynamoDB Table | KMS Key |
|-------------|-----------|----------------|---------|
| Dev | `aws-infra-terraform-state-dev` | `aws-infra-terraform-locks-dev` | `alias/aws-infra-terraform-state-dev` |
| Staging | `aws-infra-terraform-state-staging` | `aws-infra-terraform-locks-staging` | `alias/aws-infra-terraform-state-staging` |
| Prod | `aws-infra-terraform-state-prod` | `aws-infra-terraform-locks-prod` | `alias/aws-infra-terraform-state-prod` |

### State Security
- **Encryption**: All state files encrypted with KMS
- **Versioning**: S3 versioning enabled for state recovery
- **Locking**: DynamoDB prevents concurrent modifications
- **SSL**: TLS enforced for all state operations
- **Access**: Restricted to authorized IAM roles only

---

## Security

### Defense in Depth

```
Layer 1: Network ACLs      - Subnet-level traffic filtering
Layer 2: Security Groups   - Instance-level traffic filtering
Layer 3: IAM Policies      - Identity-based access control
Layer 4: Encryption        - At-rest and in-transit
Layer 5: VPC Endpoints     - Private AWS service access
Layer 6: Flow Logs         - Network traffic auditing
Layer 7: CloudWatch        - Real-time monitoring and alerts
```

### Encryption at Every Layer

| Component | Method | Key Management |
|-----------|--------|---------------|
| EBS Volumes | AES-256 | Customer-managed KMS |
| RDS Storage | AES-256 | Customer-managed KMS |
| S3 Objects | SSE-KMS | Customer-managed KMS |
| VPC Flow Logs | AES-256 | Customer-managed KMS |
| Terraform State | AES-256 | Customer-managed KMS |
| Secrets | AES-256 | Customer-managed KMS |

### IAM: Least Privilege

All IAM roles follow the principle of least privilege:
- **EC2 Instance Profile**: SSM, CloudWatch Logs, S3 Read, ECR Pull, Secrets Read
- **RDS Monitoring Role**: CloudWatch/Logs write permissions only
- **S3 Replication Role**: Source read + destination write only
- **VPC Flow Logs Role**: CloudWatch Logs write only

### Network Security
- No public access to database tier
- Security groups reference other security groups (not CIDRs where possible)
- IMDSv2 enforced on all EC2 instances
- SSM Session Manager replaces SSH bastion hosts

---

## Cost Estimates

### Dev Environment (Monthly)

| Resource | Instance | Monthly Cost |
|----------|----------|-------------|
| EC2 (1x) | t3.micro | ~$8 |
| ALB | - | ~$16 |
| NAT Gateway (1x) | - | ~$32 |
| RDS (Single-AZ) | db.t3.micro | ~$13 |
| S3 | ~10GB | ~$0.23 |
| CloudWatch Logs | ~5GB | ~$2.50 |
| **Total** | | **~$72/month** |

### Staging Environment (Monthly)

| Resource | Instance | Monthly Cost |
|----------|----------|-------------|
| EC2 (2x) | t3.medium | ~$60 |
| ALB | - | ~$22 |
| NAT Gateway (3x) | - | ~$97 |
| RDS (Multi-AZ) | db.t3.medium | ~$130 |
| S3 | ~50GB | ~$1.15 |
| CloudWatch | ~20GB | ~$10 |
| **Total** | | **~$320/month** |

### Production Environment (Monthly)

| Resource | Instance | Monthly Cost |
|----------|----------|-------------|
| EC2 (3x avg) | t3.medium | ~$90 |
| ALB | - | ~$22 |
| NAT Gateway (3x) | - | ~$97 |
| RDS (Multi-AZ) | db.t3.medium | ~$130 |
| RDS Read Replica | db.t3.medium | ~$65 |
| S3 + CRR | ~200GB | ~$5 |
| CloudWatch | ~50GB | ~$25 |
| KMS Keys | ~10 keys | ~$10 |
| **Total** | | **~$444/month** |

*Note: Costs are estimates based on us-east-1 pricing as of 2024. Actual costs vary by usage. Use the [AWS Pricing Calculator](https://calculator.aws/) for precise estimates.*

---

## Monitoring

### CloudWatch Alarms

| Service | Metric | Threshold | Action |
|---------|--------|-----------|--------|
| EC2/ASG | CPUUtilization | > 60% for 4 min | Scale up |
| EC2/ASG | CPUUtilization | < 10% for 25 min | Alert (over-provisioned) |
| ALB | UnHealthyHostCount | > 0 for 1 min | Alert |
| RDS | CPUUtilization | > 80% for 15 min | Alert |
| RDS | FreeStorageSpace | < 5 GB for 5 min | Alert |
| RDS | FreeableMemory | < 256 MB for 15 min | Alert |
| RDS | DatabaseConnections | > 80 for 10 min | Alert |

### Log Groups

| Log Group | Retention | Content |
|-----------|-----------|---------|
| `/aws/vpc/<env>-flowlogs` | 7-90 days | VPC network flows |
| `/aws/rds/instance/<id>/postgresql` | 30-90 days | PostgreSQL logs |
| `/aws/ec2/<project>-<env>` | 30-90 days | Application logs |
| `/aws/alb/<project>-<env>` | 30 days | ALB access logs |

---

## Security Considerations

### Shared Responsibility Model

This project handles infrastructure security. Application-level security (input validation, authentication, authorization) remains the responsibility of the application team.

### Compliance

| Control | Implementation |
|---------|---------------|
| Encryption at rest | KMS with automatic rotation |
| Encryption in transit | TLS 1.3, SSL enforcement on RDS |
| Network segmentation | 3-tier subnet architecture |
| Access logging | VPC flow logs, S3 access logs, ALB access logs |
| Audit trail | CloudTrail integration, all API calls logged |
| Credential management | Secrets Manager with automatic rotation |
| Least privilege | Per-service IAM roles |

### Known Limitations

- **ACM Certificate**: HTTPS requires a valid ACM certificate (not created by this project)
- **Route 53**: DNS records must be configured separately
- **CloudTrail**: Organization-level CloudTrail not included
- **WAF**: Web Application Firewall not included (recommend adding for production)

---

## Future Improvements

### Near Term (Next 3 Months)

- [ ] **Container Support**: Add ECR, ECS/Fargate module for containerized workloads
- [ ] **CI/CD Pipeline**: GitHub Actions workflow for automated plan/apply
- [ ] **WAF Integration**: Web Application Firewall with managed rule sets
- [ ] **Route 53**: Automated DNS record management
- [ ] **CloudFront**: CDN for static asset delivery

### Medium Term (3-6 Months)

- [ ] **ElastiCache**: Redis cluster for session caching
- [ ] **EKS Module**: Kubernetes cluster option
- [ ] **Backup Vault**: AWS Backup for centralized backup management
- [ ] **Config Rules**: AWS Config for compliance monitoring
- [ ] **GuardDuty**: Threat detection integration

### Long Term (6-12 Months)

- [ ] **Multi-Region**: Active-active multi-region deployment
- [ ] **Service Mesh**: AWS App Mesh or Istio on EKS
- [ ] **GitOps**: ArgoCD/Flux for GitOps-based deployments
- [ ] **Cost Optimization**: Spot instance integration, savings plans
- [ ] **DR Automation**: Automated failover runbooks

---

## Troubleshooting

### Common Issues

**Terraform init fails with "bucket not found"**
```bash
# Run the backend initialization script first
./scripts/init-backend.sh dev
```

**State lock timeout**
```bash
# Check for stale lock in DynamoDB
aws dynamodb scan --table-name aws-infra-terraform-locks-dev

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

**RDS creation timeout**
```bash
# Increase timeout
terraform apply -var-file=terraform.tfvars -timeout=60m
```

**Permission denied errors**
```bash
# Verify IAM policy is attached
aws iam simulate-principal-policy \
  --policy-source-arn <role-arn> \
  --action-names "ec2:CreateVpc"
```

### Getting Help

1. Check [docs/architecture.md](docs/architecture.md) for detailed architecture information
2. Run `./tests/validate.sh` to check configuration
3. Review module README files in `modules/<module>/README.md`
4. Check AWS Service Health Dashboard for regional issues

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following [Terraform style conventions](https://developer.hashicorp.com/terraform/language/syntax/style)
4. Run validation: `./tests/validate.sh`
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/)
6. Push and create a Pull Request

### Commit Message Format

```
<type>(<scope>): <description>

<body>

<footer>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

> **Disclaimer**: This project creates real AWS resources that incur costs. Always review the plan before applying and destroy resources when not needed. Use `terraform plan` to preview changes and costs.
