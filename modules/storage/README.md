# Storage Module

A production-ready Terraform module for creating secure S3 buckets with encryption, versioning, lifecycle policies, and access logging.

## Features

- **S3 Bucket** with unique name generation
- **Server-side encryption** with SSE-S3 (AES256) or SSE-KMS
- **KMS key** with automatic rotation for SSE-KMS
- **Versioning** for object recovery and protection
- **Lifecycle policies** for cost optimization (transition to IA, Glacier)
- **Access logging** to a separate logging bucket
- **Block public access** for security compliance
- **CORS configuration** for web application access
- **Object Lock** for compliance and governance
- **Cross-region replication** for disaster recovery
- **Event notifications** to SNS
- **Website hosting** for static assets (optional)
- **Bucket policies** denying unencrypted uploads

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  environment = "prod"
  project_name = "myapp"

  bucket_name_override = "myapp-prod-assets"

  enable_versioning      = true
  enable_encryption      = true
  encryption_type        = "SSE-KMS"
  enable_access_logging  = true
  enable_lifecycle_policy = true

  transition_to_ia_days     = 30
  transition_to_glacier_days = 90
  noncurrent_version_expiration_days = 180

  enable_replication              = true
  replication_destination_region  = "us-west-2"

  enable_object_lock             = true
  object_lock_retention_days     = 30

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
| bucket_name_override | Override bucket name | `string` | `""` | no |
| enable_versioning | Enable versioning | `bool` | `true` | no |
| enable_encryption | Enable encryption | `bool` | `true` | no |
| encryption_type | SSE-S3 or SSE-KMS | `string` | `"SSE-KMS"` | no |
| enable_access_logging | Enable access logging | `bool` | `true` | no |
| enable_lifecycle_policy | Enable lifecycle policies | `bool` | `true` | no |
| transition_to_ia_days | Days to transition to IA | `number` | `30` | no |
| transition_to_glacier_days | Days to transition to Glacier | `number` | `90` | no |
| enable_replication | Enable cross-region replication | `bool` | `false` | no |
| block_public_access | Block all public access | `bool` | `true` | no |
| enable_object_lock | Enable Object Lock | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | Bucket ID (name) |
| bucket_arn | Bucket ARN |
| bucket_name | Bucket name |
| kms_key_arn | KMS key ARN |
| logging_bucket_id | Logging bucket ID |
| website_endpoint | Website endpoint |
| encryption_type | Encryption type |

## Security

- Public access is blocked by default
- Unencrypted uploads are denied by bucket policy
- KMS encryption with automatic key rotation
- Object Lock prevents object deletion
- Access logs capture all bucket access
