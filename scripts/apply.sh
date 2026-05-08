#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Terraform Apply
# ---------------------------------------------------------------------------
# Runs terraform apply for the specified environment with safety checks.
# Requires plan file for production. Auto-approves for dev.
#
# Usage: ./apply.sh <environment> [plan-file]
#   environment: dev, staging, or prod
#   plan-file:   (optional) path to plan file. Required for prod.
# ---------------------------------------------------------------------------

set -euo pipefail

ENVIRONMENT=${1:-}
PLAN_FILE=${2:-}
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
  echo "Usage: $0 <environment> [plan-file]"
  echo "  environment: dev, staging, or prod"
  echo "  plan-file:   (optional) path to plan file. Required for prod."
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

  cd "$ENV_DIR"

  # Production safety checks
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo ""
    log_warn "=== PRODUCTION DEPLOYMENT SAFETY CHECKS ==="
    echo ""

    if [[ -z "$PLAN_FILE" ]]; then
      log_error "Plan file is required for production deployments."
      log_info "Run: ./scripts/plan.sh prod"
      log_info "Then: $0 prod <plan-file>"
      exit 1
    fi

    if [[ ! -f "$PLAN_FILE" ]]; then
      log_error "Plan file not found: $PLAN_FILE"
      exit 1
    fi

    # Verify plan file freshness (< 1 hour)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      PLAN_AGE=$(( ($(date +%s) - $(stat -f%m "$PLAN_FILE")) / 60 ))
    else
      PLAN_AGE=$(( ($(date +%s) - $(stat -c%Y "$PLAN_FILE")) / 60 ))
    fi

    if [[ $PLAN_AGE -gt 60 ]]; then
      log_warn "Plan file is older than 60 minutes ($PLAN_AGE min). Consider re-planning."
      read -p "Continue anyway? (yes/no): " CONFIRM
      if [[ "$CONFIRM" != "yes" ]]; then
        log_info "Deployment cancelled"
        exit 0
      fi
    fi

    # Manual approval
    echo ""
    log_warn "You are about to apply changes to PRODUCTION."
    read -p "Type 'deploy-to-production' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "deploy-to-production" ]]; then
      log_info "Deployment cancelled"
      exit 0
    fi
  fi

  log_info "Running terraform apply for environment: $ENVIRONMENT"

  if [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]]; then
    terraform apply "$PLAN_FILE"
  elif [[ "$ENVIRONMENT" == "dev" ]]; then
    terraform apply -var-file="terraform.tfvars" -auto-approve
  else
    terraform apply -var-file="terraform.tfvars"
  fi

  log_success "Terraform apply completed for $ENVIRONMENT"

  # Save outputs
  OUTPUTS_FILE="outputs-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).json"
  terraform output -json > "$OUTPUTS_FILE"
  log_success "Outputs saved to: $ENV_DIR/$OUTPUTS_FILE"
}

main "$@"
