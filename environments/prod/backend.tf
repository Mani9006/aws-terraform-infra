# ---------------------------------------------------------------------------
# Production Environment - Backend Configuration
# ---------------------------------------------------------------------------
# Remote state in dedicated S3 bucket with DynamoDB locking and KMS
# encryption. State locking prevents concurrent modifications.
# ---------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "aws-infra-terraform-state-prod"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-infra-terraform-locks-prod"
    encrypt        = true
    kms_key_id     = "alias/aws-infra-terraform-state-prod"
  }
}
