#!/usr/bin/env bash
set -euo pipefail

########################################
# Config                               #
########################################

# Local folder with your built site (index.html at the root)
LOCAL_SITE_DIR="site"

# Repo root (directory containing this script)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${REPO_ROOT}/infra"

# Optional: copy deploy.env.example to deploy.env and set values manually.
# Values in deploy.env override Terraform outputs.
if [[ -f "${REPO_ROOT}/deploy.env" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/deploy.env"
fi

########################################
# Helpers                              #
########################################

die() { echo "ERROR: $*" >&2; exit 1; }

read_terraform_output() {
  local name="$1"
  if [[ -f "${INFRA_DIR}/terraform.tfstate" ]]; then
    terraform -chdir="${INFRA_DIR}" output -raw "${name}" 2>/dev/null || true
  fi
}

if [[ -z "${BUCKET:-}" ]]; then
  BUCKET="$(read_terraform_output site_bucket_name)"
fi

if [[ -z "${DISTRIBUTION_ID:-}" ]]; then
  DISTRIBUTION_ID="$(read_terraform_output cloudfront_distribution_id)"
fi

[[ -n "${BUCKET:-}" ]] || die "BUCKET is not set. Run 'terraform apply' in infra/, or create deploy.env from deploy.env.example."
[[ -n "${DISTRIBUTION_ID:-}" ]] || die "DISTRIBUTION_ID is not set. Run 'terraform apply' in infra/, or create deploy.env from deploy.env.example."

########################################
# Deploy                               #
########################################

echo "----------------------------------------"
echo " Deploying site to S3 and invalidating CloudFront"
echo " Bucket:       ${BUCKET}"
echo " Site dir:     ${LOCAL_SITE_DIR}/"
echo " Distribution: ${DISTRIBUTION_ID}"
echo "----------------------------------------"
echo ""

[[ -d "${REPO_ROOT}/${LOCAL_SITE_DIR}" ]] || die "Local site directory '${LOCAL_SITE_DIR}' not found."
[[ -f "${REPO_ROOT}/${LOCAL_SITE_DIR}/index.html" ]] || die "Missing ${LOCAL_SITE_DIR}/index.html."

echo "AWS identity:"
aws sts get-caller-identity --output json
echo ""

echo "Syncing ${LOCAL_SITE_DIR}/ to s3://${BUCKET}/ ..."
aws s3 sync "${REPO_ROOT}/${LOCAL_SITE_DIR}/" "s3://${BUCKET}/" \
  --delete \
  --exclude ".DS_Store" \
  --exclude "*/.DS_Store"
echo ""

echo "Validating CloudFront distribution ID exists..."
if ! aws cloudfront get-distribution --id "${DISTRIBUTION_ID}" >/dev/null 2>&1; then
  echo "WARNING: Distribution '${DISTRIBUTION_ID}' not found for current AWS identity."
  echo "         Skipping invalidation. (Check AWS_PROFILE / credentials.)"
else
  echo "Creating CloudFront invalidation for /* ..."
  aws cloudfront create-invalidation \
    --distribution-id "${DISTRIBUTION_ID}" \
    --paths "/*" >/dev/null
  echo "Invalidation submitted."
fi

echo ""
echo "Done."
