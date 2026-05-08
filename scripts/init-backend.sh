#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Initialize Terraform Backend
# ---------------------------------------------------------------------------
# Creates the S3 bucket and DynamoDB table required for remote state
# management. Run this once per environment before first terraform init.
#
# Usage: ./init-backend.sh <environment>
#   environment: dev, staging, or prod
# ---------------------------------------------------------------------------

set -euo pipefail

ENVIRONMENT=${1:-}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="aws-infra"
AWS_REGION="us-east-1"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
  echo "Usage: $0 <environment>"
  echo "  environment: dev, staging, or prod"
  exit 1
}

validate_environment() {
  if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment not specified"
    usage
  fi

  if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    exit 1
  fi
}

check_aws_cli() {
  if ! command -v aws &>/dev/null; then
    log_error "AWS CLI is not installed. Install it first: https://docs.aws.amazon.com/cli/"
    exit 1
  fi

  if ! aws sts get-caller-identity &>/dev/null; then
    log_error "AWS credentials not configured. Run 'aws configure' first."
    exit 1
  fi

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  log_info "Authenticated with AWS account: $ACCOUNT_ID"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  validate_environment
  check_aws_cli

  BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ENVIRONMENT}"
  DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks-${ENVIRONMENT}"
  KMS_KEY_ALIAS="alias/${PROJECT_NAME}-terraform-state-${ENVIRONMENT}"

  log_info "Initializing Terraform backend for environment: $ENVIRONMENT"
  log_info "  Bucket:     $BUCKET_NAME"
  log_info "  DynamoDB:   $DYNAMODB_TABLE"
  log_info "  KMS Alias:  $KMS_KEY_ALIAS"

  # ---------------------------------------------------------------------------
  # Create KMS Key for State Encryption
  # ---------------------------------------------------------------------------
  log_info "Creating KMS key for state encryption..."

  if aws kms describe-key --key-id "$KMS_KEY_ALIAS" &>/dev/null; then
    log_warn "KMS key alias '$KMS_KEY_ALIAS' already exists, reusing"
    KMS_KEY_ID=$(aws kms describe-key --key-id "$KMS_KEY_ALIAS" --query 'KeyMetadata.KeyId' --output text)
  else
    KMS_KEY_ID=$(aws kms create-key \
      --description "KMS key for Terraform state encryption - ${ENVIRONMENT}" \
      --key-usage ENCRYPT_DECRYPT \
      --origin AWS_KMS \
      --bypass-policy-lockout-safety-check \
      --query 'KeyMetadata.KeyId' \
      --output text)

    aws kms create-alias \
      --alias-name "$KMS_KEY_ALIAS" \
      --target-key-id "$KMS_KEY_ID"

    aws kms enable-key-rotation --key-id "$KMS_KEY_ID"
    log_success "KMS key created: $KMS_KEY_ID"
  fi

  # ---------------------------------------------------------------------------
  # Create S3 Bucket
  # ---------------------------------------------------------------------------
  log_info "Creating S3 bucket for remote state..."

  if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    log_warn "S3 bucket '$BUCKET_NAME' already exists, skipping creation"
  else
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION"
    else
      aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi

    # Enable versioning
    aws s3api put-bucket-versioning \
      --bucket "$BUCKET_NAME" \
      --versioning-configuration Status=Enabled

    # Enable encryption
    aws s3api put-bucket-encryption \
      --bucket "$BUCKET_NAME" \
      --server-side-encryption-configuration '{
        "Rules": [{
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "aws:kms",
            "KMSMasterKeyID": "'"$KMS_KEY_ID"'"
          },
          "BucketKeyEnabled": true
        }]
      }'

    # Block public access
    aws s3api put-public-access-block \
      --bucket "$BUCKET_NAME" \
      --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    # Enable access logging lifecycle
    aws s3api put-bucket-lifecycle-configuration \
      --bucket "$BUCKET_NAME" \
      --lifecycle-configuration '{
        "Rules": [{
          "ID": "delete-old-versions",
          "Status": "Enabled",
          "NoncurrentVersionExpiration": {"NoncurrentDays": 90}
        }]
      }'

    # Bucket policy
    aws s3api put-bucket-policy \
      --bucket "$BUCKET_NAME" \
      --policy '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "EnforceEncryptedConnections",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/*",
            "Condition": {
              "Bool": {"aws:SecureTransport": "false"}
            }
          }
        ]
      }'

    log_success "S3 bucket created and configured: $BUCKET_NAME"
  fi

  # ---------------------------------------------------------------------------
  # Create DynamoDB Table for State Locking
  # ---------------------------------------------------------------------------
  log_info "Creating DynamoDB table for state locking..."

  if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" &>/dev/null; then
    log_warn "DynamoDB table '$DYNAMODB_TABLE' already exists, skipping creation"
  else
    aws dynamodb create-table \
      --table-name "$DYNAMODB_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --tags Key=Environment,Value="$ENVIRONMENT" Key=Project,Value="$PROJECT_NAME"

    # Enable point-in-time recovery
    aws dynamodb update-continuous-backups \
      --table-name "$DYNAMODB_TABLE" \
      --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

    log_success "DynamoDB table created: $DYNAMODB_TABLE"
  fi

  # ---------------------------------------------------------------------------
  # Summary
  # ---------------------------------------------------------------------------
  echo ""
  log_success "Backend initialization complete for '$ENVIRONMENT}'!"
  echo ""
  echo "Backend configuration:"
  echo "  Bucket:       $BUCKET_NAME"
  echo "  DynamoDB:     $DYNAMODB_TABLE"
  echo "  KMS Key:      $KMS_KEY_ALIAS"
  echo "  KMS Key ID:   $KMS_KEY_ID"
  echo "  Region:       $AWS_REGION"
  echo ""
  echo "Next steps:"
  echo "  cd environments/$ENVIRONMENT"
  echo "  terraform init"
  echo "  terraform plan -var-file=terraform.tfvars"
}

main "$@"
