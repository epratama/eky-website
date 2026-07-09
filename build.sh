#!/bin/bash
set -e

STACK_NAME="${STACK_NAME:-resume-website}"
S3_BUCKET="${S3_BUCKET:-}"
LAMBDA_URL="${LAMBDA_URL:-}"
HCAPTCHA_SITE_KEY="${HCAPTCHA_SITE_KEY:-}"

echo "=== Building frontend ==="
pushd frontend > /dev/null
VITE_LAMBDA_URL="$LAMBDA_URL" VITE_HCAPTCHA_SITEKEY="$HCAPTCHA_SITE_KEY" npx vite build
popd > /dev/null

if [ -n "$S3_BUCKET" ]; then
  echo "=== Uploading to S3: $S3_BUCKET ==="
  aws s3 sync frontend/dist/ "s3://$S3_BUCKET/" --delete --cache-control "max-age=31536000,immutable"
  aws cloudfront create-invalidation --distribution-id "$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistribution`].OutputValue' --output text 2>/dev/null || echo '')" --paths "/*" 2>/dev/null || echo "CloudFront invalidation skipped (no distribution found)"
fi

echo "=== Done ==="
