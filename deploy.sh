#!/bin/bash
# deploy.sh — build and deploy the resume website
# Usage: ./deploy.sh <stack-name>
set -e

STACK_NAME="${1:?Usage: ./deploy.sh <stack-name>}"

# Verify stack exists
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1; then
  echo "Error: stack '$STACK_NAME' not found"
  exit 1
fi

# Fetch all values in one API call (depends on jq)
if ! command -v jq > /dev/null 2>&1; then
  echo "Error: jq is required (brew install jq)"
  exit 1
fi

DATA=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --output json)
S3_BUCKET=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="S3Bucket") | .OutputValue')
LAMBDA_URL=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="LambdaURL") | .OutputValue')
HCAPTCHA_SITEKEY=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="HCaptchaSiteKey") | .ParameterValue')
DIST_DOMAIN=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="WebsiteURL") | .OutputValue' | cut -d'/' -f3)
DIST_ID="${DIST_DOMAIN%%.*}"

echo "Stack:    $STACK_NAME"
echo "Bucket:   $S3_BUCKET"
echo "API:      $LAMBDA_URL"
echo "CDN:      $DIST_DOMAIN"
echo ""

# Build
echo "=== Building ==="
cd "$(dirname "$0")/frontend"
VITE_LAMBDA_URL="$LAMBDA_URL" VITE_HCAPTCHA_SITEKEY="$HCAPTCHA_SITEKEY" npm run build
cd ..

# Upload
echo "=== Uploading to S3 ==="
aws s3 sync frontend/dist/ "s3://$S3_BUCKET/" --delete

# Invalidate CloudFront
echo "=== Invalidating CloudFront: $DIST_ID ==="
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --output text

echo ""
echo "=== Done: https://$DIST_DOMAIN ==="
