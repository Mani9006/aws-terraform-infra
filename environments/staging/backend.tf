# ---------------------------------------------------------------------------
# Staging Environment - Backend Configuration
# ---------------------------------------------------------------------------
# Remote state stored in S3 with DynamoDB locking. Separate bucket from dev
# to prevent state corruption across environments.
# ---------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "aws-infra-terraform-state-staging"
    key            = "environments/staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-infra-terraform-locks-staging"
    encrypt        = true
    kms_key_id     = "alias/aws-infra-terraform-state-staging"
  }
}
