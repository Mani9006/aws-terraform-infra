#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Terraform Validation Script
# ---------------------------------------------------------------------------
# Validates all Terraform configurations including syntax, formatting,
# and security checks using terraform validate, fmt, and checkov.
#
# Usage: ./tests/validate.sh [environment]
#   environment: dev, staging, prod, or all (default: all)
# ---------------------------------------------------------------------------

set -euo pipefail

ENVIRONMENT=${1:-"all"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ERRORS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

usage() {
  echo "Usage: $0 [environment]"
  echo "  environment: dev, staging, prod, or all (default: all)"
  exit 1
}

# ---------------------------------------------------------------------------
# Check Prerequisites
# ---------------------------------------------------------------------------

check_prerequisites() {
  log_info "Checking prerequisites..."

  if ! command -v terraform &>/dev/null; then
    log_error "Terraform is not installed. Install from https://developer.hashicorp.com/terraform/downloads"
    exit 1
  fi

  TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
  log_info "Terraform version: $TERRAFORM_VERSION"

  if ! command -v checkov &>/dev/null; then
    log_warn "Checkov is not installed. Skipping security checks."
    log_info "Install with: pip install checkov"
    SKIP_CHECKOV=1
  else
    SKIP_CHECKOV=0
    CHECKOV_VERSION=$(checkov --version)
    log_info "Checkov version: $CHECKOV_VERSION"
  fi

  log_success "Prerequisites check complete"
}

# ---------------------------------------------------------------------------
# Validate Module
# ---------------------------------------------------------------------------

validate_module() {
  local module_path=$1
  local module_name=$2

  log_info "Validating module: $module_name"
  cd "$module_path"

  # Initialize module (backend disabled)
  if ! terraform init -backend=false -input=false &>/dev/null; then
    log_error "Failed to initialize module: $module_name"
    ERRORS=$((ERRORS + 1))
    return 1
  fi

  # Validate
  if terraform validate; then
    log_success "Validation passed: $module_name"
  else
    log_error "Validation failed: $module_name"
    ERRORS=$((ERRORS + 1))
    return 1
  fi

  # Format check
  if terraform fmt -check -recursive -diff; then
    log_success "Format check passed: $module_name"
  else
    log_warn "Format issues found in: $module_name. Run 'terraform fmt -recursive' to fix."
    ERRORS=$((ERRORS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Validate Environment
# ---------------------------------------------------------------------------

validate_environment() {
  local env=$1
  local env_path="$PROJECT_ROOT/environments/$env"

  if [[ ! -d "$env_path" ]]; then
    log_error "Environment directory not found: $env_path"
    ERRORS=$((ERRORS + 1))
    return 1
  fi

  log_info "Validating environment: $env"
  cd "$env_path"

  # Initialize (backend disabled for validation)
  if ! terraform init -backend=false -input=false &>/dev/null; then
    log_error "Failed to initialize environment: $env"
    ERRORS=$((ERRORS + 1))
    return 1
  fi

  # Validate
  if terraform validate; then
    log_success "Validation passed: $env"
  else
    log_error "Validation failed: $env"
    ERRORS=$((ERRORS + 1))
    return 1
  fi

  # Format check
  if terraform fmt -check -diff; then
    log_success "Format check passed: $env"
  else
    log_warn "Format issues found in: $env. Run 'terraform fmt' to fix."
    ERRORS=$((ERRORS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Security Checks
# ---------------------------------------------------------------------------

run_security_checks() {
  log_info "Running security checks with Checkov..."

  if [[ "$SKIP_CHECKOV" == "1" ]]; then
    log_warn "Skipping Checkov security checks"
    return 0
  fi

  cd "$PROJECT_ROOT"

  if checkov --directory "$PROJECT_ROOT/modules" \
    --config-file "$PROJECT_ROOT/tests/checkov-config.yml" \
    --compact \
    --quiet; then
    log_success "Security checks passed"
  else
    log_warn "Security checks found issues. Review output above."
  fi
}

# ---------------------------------------------------------------------------
# Check Documentation
# ---------------------------------------------------------------------------

check_documentation() {
  log_info "Checking documentation..."

  local required_docs=(
    "$PROJECT_ROOT/README.md"
    "$PROJECT_ROOT/docs/architecture.md"
    "$PROJECT_ROOT/modules/vpc/README.md"
    "$PROJECT_ROOT/modules/compute/README.md"
    "$PROJECT_ROOT/modules/database/README.md"
    "$PROJECT_ROOT/modules/storage/README.md"
    "$PROJECT_ROOT/LICENSE"
  )

  for doc in "${required_docs[@]}"; do
    if [[ -f "$doc" ]]; then
      log_success "Documentation exists: $(basename "$doc")"
    else
      log_error "Missing documentation: $(basename "$doc")"
      ERRORS=$((ERRORS + 1))
    fi
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  echo ""
  echo "============================================================"
  echo "  Terraform Validation Suite"
  echo "============================================================"
  echo ""

  if [[ "$ENVIRONMENT" != "all" && ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    usage
  fi

  check_prerequisites

  echo ""
  log_info "=== Validating Modules ==="
  validate_module "$PROJECT_ROOT/modules/vpc" "vpc"
  validate_module "$PROJECT_ROOT/modules/compute" "compute"
  validate_module "$PROJECT_ROOT/modules/database" "database"
  validate_module "$PROJECT_ROOT/modules/storage" "storage"

  echo ""
  log_info "=== Validating Environments ==="
  if [[ "$ENVIRONMENT" == "all" ]]; then
    validate_environment "dev"
    validate_environment "staging"
    validate_environment "prod"
  else
    validate_environment "$ENVIRONMENT"
  fi

  echo ""
  log_info "=== Security Checks ==="
  run_security_checks

  echo ""
  log_info "=== Documentation Checks ==="
  check_documentation

  echo ""
  echo "============================================================"
  if [[ $ERRORS -eq 0 ]]; then
    log_success "All validation checks passed!"
    exit 0
  else
    log_error "Validation completed with $ERRORS issue(s)"
    exit 1
  fi
}

main "$@"
