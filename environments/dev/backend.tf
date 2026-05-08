# ---------------------------------------------------------------------------
# Dev Environment - Backend Configuration
# ---------------------------------------------------------------------------
# Remote state stored in S3 with DynamoDB locking for team collaboration.
# The backend bucket and DynamoDB table must be created by init-backend.sh
# before running terraform init.
# ---------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "aws-infra-terraform-state-dev"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-infra-terraform-locks-dev"
    encrypt        = true
    kms_key_id     = "alias/aws-infra-terraform-state-dev"

    # State locking with DynamoDB for team safety
    # Workspace key prefix enables workspace-based isolation
  }
}
