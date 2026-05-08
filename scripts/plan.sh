#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Terraform Plan
# ---------------------------------------------------------------------------
# Runs terraform plan for the specified environment with best practices.
#
# Usage: ./plan.sh <environment> [terraform-options]
#   environment: dev, staging, or prod
# ---------------------------------------------------------------------------

set -euo pipefail

ENVIRONMENT=${1:-}
shift 2>/dev/null || true
EXTRA_ARGS="${*:-}"
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
  echo "Usage: $0 <environment> [terraform-options]"
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

  log_info "Running terraform plan for environment: $ENVIRONMENT"
  log_info "  Directory: $ENV_DIR"
  log_info "  Extra args: $EXTRA_ARGS"

  cd "$ENV_DIR"

  # Check if terraform is initialized
  if [[ ! -d ".terraform" ]]; then
    log_warn "Terraform not initialized. Running init first..."
    terraform init -backend-config="backend.tf"
  fi

  # Run terraform plan
  PLAN_FILE="tfplan-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
  log_info "Plan output will be saved to: $PLAN_FILE"

  terraform plan \
    -var-file="terraform.tfvars" \
    -out="$PLAN_FILE" \
    $EXTRA_ARGS

  log_success "Plan saved to: $ENV_DIR/$PLAN_FILE"

  # Show cost estimate hint
  echo ""
  log_info "To apply this plan: ./scripts/apply.sh $ENVIRONMENT"
  log_info "To see detailed plan: terraform show $PLAN_FILE"
}

main "$@"
