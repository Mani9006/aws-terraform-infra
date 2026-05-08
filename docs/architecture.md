# Architecture Documentation

## Overview

This Infrastructure as Code project provides a complete, production-ready AWS environment using Terraform. The architecture follows AWS Well-Architected Framework principles across all five pillars: Operational Excellence, Security, Reliability, Performance Efficiency, and Cost Optimization.

## Architecture Diagram

```
                                   +------------------+
                                   |     Route 53     |
                                   |  (DNS / Health)  |
                                   +--------+---------+
                                            |
                                            v
+-------------------------------------------+-----------------------------------+
|                                AWS Region (us-east-1)                        |
|                                                                             |
|  +-------------------+    +-------------------------------------------+     |
|  |   AWS WAF         |    |         Application Load Balancer         |     |
|  |   (Web ACL)       |<-->|          (Public Subnets)                 |     |
|  |                   |    |   HTTP:80  |  HTTPS:443                   |     |
|  +-------------------+    +--------------------+----------------------+     |
|                                                |                            |
|                           +--------------------v----------------------+     |
|                           |          Target Group (Health)            |     |
|                           |            Health Check: /health          |     |
|                           +--------------------+----------------------+     |
|                                                |                            |
|                           +--------------------v----------------------+     |
|                           |         Auto Scaling Group                |     |
|                           |         (Private Subnets)                 |     |
|                           |   min: 2  desired: 3  max: 10             |     |
|                           |   +----------+  +----------+  +--------+  |     |
|                           |   | EC2 t3.m |  | EC2 t3.m |  | EC2... |  |     |
|                           |   | (AZ 1a)  |  | (AZ 1b)  |  | AZ 1c  |  |     |
|                           |   +----------+  +----------+  +--------+  |     |
|                           +--------------------+----------------------+     |
|                                                |                            |
|                           +--------------------v----------------------+     |
|                           |         Amazon RDS PostgreSQL             |     |
|                           |         (Database Subnets)                |     |
|                           |   Multi-AZ: Yes   Encrypted: Yes          |     |
|                           |   +----------+       +----------+         |     |
|                           |   | Primary  |<---->| Standby  |         |     |
|                           |   | (AZ 1a)  |  sync | (AZ 1b)  |         |     |
|                           |   +----------+       +----------+         |     |
|                           |         [ Read Replica: Optional ]        |     |
|                           +--------------------+----------------------+     |
|                                                |                            |
|                           +--------------------v----------------------+     |
|                           |          Amazon S3                        |     |
|                           |   Application Assets + Access Logs        |     |
|                           |   [ Cross-Region Replication: us-west-2 ] |     |
|                           +--------------------+----------------------+     |
|                                                                             |
|  +-----------------------------------+----------------------------------+   |
|  |              Public Subnets        |          Private Subnets        |   |
|  |  10.x.1.0/24 | 10.x.2.0/24       |  10.x.4.0/24 | 10.x.5.0/24    |   |
|  |  ALB | NAT GW | Bastion (SSM)     |  EC2 | ASG   | VPC Endpoints   |   |
|  +-----------------------------------+----------------------------------+   |
|                                                                             |
|  +---------------------------------------------------------------------------+
|  |                              VPC 10.x.0.0/16                              |
|  |   Flow Logs -> CloudWatch  |  NACLs (Defense in Depth)                    |
|  |   IGW | S3 Endpoint | SSM Endpoint | CloudWatch Endpoint                    |
|  +---------------------------------------------------------------------------+
|                                                                             |
+-----------------------------------------------------------------------------+

                              MONITORING & SECURITY

  +----------------+  +----------------+  +----------------+  +-------------+
  | CloudWatch     |  | CloudWatch     |  | Secrets        |  | IAM Roles   |
  | Alarms (ASG)   |  | Alarms (RDS)   |  | Manager        |  | (Least Priv)|
  +----------------+  +----------------+  +----------------+  +-------------+
  | SNS Topic      |  | SNS Topic      |  | KMS Keys       |  | SSM Session |
  | (Notifications)|  | (Notifications)|  | (Encryption)   |  | Manager     |
  +----------------+  +----------------+  +----------------+  +-------------+
```

## Network Architecture

### VPC Design
- **CIDR Block**: Configurable per environment (10.0/10.1/10.2.0.0/16)
- **DNS Hostnames/Support**: Enabled for service discovery
- **Flow Logs**: All traffic captured to CloudWatch with KMS encryption
- **Network ACLs**: Defense-in-depth at subnet level

### Subnet Tiers
| Tier | Purpose | Internet Access | Example CIDR |
|------|---------|----------------|--------------|
| Public | ALB, NAT Gateways | Via IGW | 10.x.1.0/24 |
| Private | EC2, ASG | Via NAT GW | 10.x.4.0/24 |
| Database | RDS | No direct access | 10.x.7.0/24 |

### NAT Gateways
- **Dev**: Single NAT gateway (cost-optimized)
- **Staging/Prod**: Per-AZ NAT gateways (high availability)
- Elastic IPs for stable outbound addressing

### VPC Endpoints
- **S3 Gateway**: Private S3 access without internet
- **SSM Interface**: Session Manager connectivity
- **CloudWatch Logs**: Log shipping without internet

## Compute Architecture

### Launch Template
- Latest Amazon Linux 2023 AMI (auto-resolved)
- Encrypted EBS volumes (GP3) with customer-managed KMS
- IMDSv2 enforced (metadata service v2)
- IAM instance profile with least privilege

### Auto Scaling Group
- Min/Desired/Max configurable per environment
- Target tracking on CPU utilization (60%)
- Instance refresh for zero-downtime deployments
- Health checks via ALB (not just EC2 status)

### Application Load Balancer
- Cross-AZ load distribution
- HTTP (port 80) and optional HTTPS (port 443)
- SSL policy: TLS 1.3
- Health checks on configurable path
- Access logging to S3
- Deletion protection in production

## Database Architecture

### RDS PostgreSQL
- Multi-AZ deployment in staging and production
- Automated backups (1-35 days retention)
- Storage autoscaling up to configured max
- Performance Insights for query analysis
- Enhanced Monitoring (OS-level metrics)
- CloudWatch logs export

### Security
- SSL/TLS enforced via parameter group
- Credentials stored in Secrets Manager
- Access restricted to private subnets
- Network ACLs block all non-PostgreSQL traffic
- Encryption at rest with KMS

### Read Replica
- Optional read replica in production
- Same VPC, different AZ
- Async replication from primary

## Storage Architecture

### S3 Bucket
- Server-side encryption (SSE-KMS)
- Versioning enabled
- Lifecycle policies for cost optimization:
  - 30 days: Transition to Standard-IA
  - 90 days: Transition to Glacier
  - Configurable: Expire non-current versions
- Access logging to separate bucket
- Object Lock for compliance (production)
- Cross-region replication (production)

### Bucket Security
- All public access blocked
- Bucket policy denies unencrypted uploads
- Denies incorrect KMS key usage
- Force SSL in transit

## Security Architecture

### Identity and Access
- **IAM Roles**: Per-service roles with least privilege
- **Instance Profiles**: No long-term credentials on instances
- **SSM Session Manager**: No SSH keys or bastion hosts needed
- **Secrets Manager**: Encrypted credential storage

### Encryption
| Layer | Method | Key Management |
|-------|--------|----------------|
| EBS Volumes | AES-256 | Customer-managed KMS |
| RDS Storage | AES-256 | Customer-managed KMS |
| S3 Objects | SSE-KMS | Customer-managed KMS |
| Flow Logs | AES-256 | Customer-managed KMS |
| Terraform State | AES-256 | Customer-managed KMS |
| Secrets | AES-256 | Customer-managed KMS |

### Network Security
- Security groups: Stateful, least privilege
- Network ACLs: Stateless, defense in depth
- No public access to database tier
- VPC endpoints for AWS services

## Monitoring Architecture

### CloudWatch
- **ASG Alarms**: High CPU, low CPU, unhealthy hosts
- **RDS Alarms**: CPU, storage, memory, connections
- **Log Groups**: VPC flow logs, PostgreSQL logs, EC2 logs

### SNS Notifications
- Separate topics per service
- RDS event subscriptions for operational events

## State Management

### Remote State
- S3 bucket with versioning enabled
- KMS encryption at rest
- DynamoDB table for state locking
- Separate buckets per environment

### Workspace Strategy
Each environment (dev/staging/prod) uses:
- Dedicated S3 bucket
- Dedicated DynamoDB table
- Dedicated KMS key
- Isolated tfvars file

## Cost Optimization

### Dev Environment
- t3.micro instances
- Single NAT gateway
- No Multi-AZ RDS
- 1-day backup retention
- Force destroy enabled

### Production Environment
- t3.medium+ instances
- Per-AZ NAT gateways
- Multi-AZ everything
- 35-day backup retention
- Cross-region replication

## Disaster Recovery

### RPO/RTO Targets
| Environment | RPO | RTO |
|-------------|-----|-----|
| Dev | 24h | 24h |
| Staging | 4h | 2h |
| Production | 1h | 1h |

### DR Strategy
- **Multi-AZ**: Automatic failover for compute and database
- **Backups**: Automated daily with configurable retention
- **Cross-Region Replication**: S3 data replicated to us-west-2
- **Read Replica**: Database replica for read scaling
