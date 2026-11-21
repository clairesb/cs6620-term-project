#!/usr/bin/env bash
# Build and deploy the React frontend to S3 + invalidate CloudFront.
# Run from the repo root: ./scripts/deploy-frontend.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/frontend"

if [[ ! -f .env.local ]]; then
  echo "frontend/.env.local is missing. Fill it from \`terraform -chdir=infra/dashboard output frontend_env_block\`."
  exit 1
fi

echo "==> npm ci"
npm ci

echo "==> vite build"
npm run build

BUCKET="$(terraform -chdir="$ROOT_DIR/infra/dashboard" output -raw frontend_bucket)"
DIST_ID="$(terraform -chdir="$ROOT_DIR/infra/dashboard" output -raw cloudfront_distribution_id)"

echo "==> aws s3 sync -> s3://$BUCKET"
aws s3 sync dist/ "s3://$BUCKET/" --delete

echo "==> cloudfront invalidation on $DIST_ID"
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" >/dev/null

echo "==> done. URL: $(terraform -chdir="$ROOT_DIR/infra/dashboard" output -raw cloudfront_url)"
