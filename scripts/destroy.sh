#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Terraform Destroy
# ---------------------------------------------------------------------------
# Runs terraform destroy for the specified environment with safety checks.
# Production destruction requires explicit confirmation.
#
# Usage: ./destroy.sh <environment>
#   environment: dev, staging, or prod
# ---------------------------------------------------------------------------

set -euo pipefail

ENVIRONMENT=${1:-}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
  echo "Usage: $0 <environment>"
  echo "  environment: dev, staging, or prod"
  exit 1
}

main() {
  if [[ -z "$ENVIRONMENT" || ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid or missing environment"
    usage
  fi

  ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"
  if [[ ! -d "$ENV_DIR" ]]; then
    log_error "Environment directory not found: $ENV_DIR"
    exit 1
  fi

  echo ""
  log_warn "=== DESTRUCTION SAFETY CHECKS ==="
  echo ""

  # Production requires extreme confirmation
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    log_error "!!! PRODUCTION DESTRUCTION REQUESTED !!!"
    echo ""
    echo "This will DESTROY ALL production infrastructure including:"
    echo "  - VPC and all networking"
    echo "  - Database (RDS with data)"
    echo "  - Compute instances and load balancers"
    echo "  - S3 buckets and all objects"
    echo ""
    echo "This action is IRREVERSIBLE."
    echo ""

    read -p "Type 'destroy-production-infrastructure' to confirm: " CONFIRM1
    if [[ "$CONFIRM1" != "destroy-production-infrastructure" ]]; then
      log_info "Destruction cancelled"
      exit 0
    fi

    read -p "Type 'i-understand-all-data-will-be-lost' to confirm again: " CONFIRM2
    if [[ "$CONFIRM2" != "i-understand-all-data-will-be-lost" ]]; then
      log_info "Destruction cancelled"
      exit 0
    fi

    # Require 60-second countdown
    log_warn "Waiting 60 seconds before destruction begins. Press Ctrl+C to cancel."
    for i in $(seq 60 -1 1); do
      printf "\r  Destroying in %2d seconds..." "$i"
      sleep 1
    done
    echo ""

  elif [[ "$ENVIRONMENT" == "staging" ]]; then
    log_warn "Staging destruction requested."
    read -p "Type 'destroy-staging' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "destroy-staging" ]]; then
      log_info "Destruction cancelled"
      exit 0
    fi
  else
    # Dev - simpler confirmation
    read -p "Are you sure you want to destroy dev environment? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
      log_info "Destruction cancelled"
      exit 0
    fi
  fi

  log_info "Running terraform destroy for environment: $ENVIRONMENT"

  cd "$ENV_DIR"

  if [[ "$ENVIRONMENT" == "dev" ]]; then
    terraform destroy -var-file="terraform.tfvars" -auto-approve
  else
    terraform destroy -var-file="terraform.tfvars"
  fi

  log_success "Terraform destroy completed for $ENVIRONMENT"
}

main "$@"
