#!/bin/bash
# deploy.sh — create/update stack + build + upload + invalidate
# Usage: ./deploy.sh <stack-name>
set -e

STACK_NAME="${1:?Usage: ./deploy.sh <stack-name>}"

# Check deps
missing=()
command -v aws > /dev/null 2>&1 || missing+=(aws)
command -v jq  > /dev/null 2>&1 || missing+=(jq)
command -v npm > /dev/null 2>&1 || missing+=(npm)
if [ ${#missing[@]} -gt 0 ]; then
  echo "Error: missing: ${missing[*]}"
  echo "Install: brew install ${missing[*]}"
  exit 1
fi

HCAPTCHA_SITEKEY="e1d21a02-d3c8-4d2e-aee0-7e3671820d2a"

# Check if stack exists, fetch current values
STACK_EXISTS=false
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1; then
  STACK_EXISTS=true
  DATA=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --output json 2>/dev/null)
  EXISTING_SENDER=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="SenderEmail") | .ParameterValue' 2>/dev/null)
  EXISTING_RECIPIENT=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="RecipientEmail") | .ParameterValue' 2>/dev/null)
  EXISTING_SITEKEY=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="HCaptchaSiteKey") | .ParameterValue' 2>/dev/null)
  echo "Stack '$STACK_NAME' exists. Current config:"
  echo "  Sender:     $EXISTING_SENDER"
  echo "  Recipient:  $EXISTING_RECIPIENT"
  echo "  SiteKey:    $EXISTING_SITEKEY"
  echo "  SiteKey now: $HCAPTCHA_SITEKEY"
else
  echo "Stack '$STACK_NAME' does not exist — will create."
fi

# Gather parameters
if [ "$STACK_EXISTS" = true ]; then
  read -p "Sender email [$EXISTING_SENDER]: " SENDER_EMAIL
  SENDER_EMAIL="${SENDER_EMAIL:-$EXISTING_SENDER}"
  read -p "Recipient email [$EXISTING_RECIPIENT]: " RECIPIENT_EMAIL
  RECIPIENT_EMAIL="${RECIPIENT_EMAIL:-$EXISTING_RECIPIENT}"
  echo "hCaptcha secret will remain unchanged unless you enter a new one."
else
  read -p "Sender email (SES verified): " SENDER_EMAIL
  read -p "Recipient email: " RECIPIENT_EMAIL
fi
read -s -p "hCaptcha secret (leave empty to keep existing): " HCAPTCHA_SECRET
echo ""

# Build parameter overrides
PARAMS=()
PARAMS+=(ParameterKey=HCaptchaSiteKey,ParameterValue="$HCAPTCHA_SITEKEY")
PARAMS+=(ParameterKey=SenderEmail,ParameterValue="$SENDER_EMAIL")
PARAMS+=(ParameterKey=RecipientEmail,ParameterValue="$RECIPIENT_EMAIL")
if [ -n "$HCAPTCHA_SECRET" ]; then
  PARAMS+=(ParameterKey=HCaptchaSecret,ParameterValue="$HCAPTCHA_SECRET")
fi

# Deploy/update stack
echo ""
echo "=== Deploying stack: $STACK_NAME ==="
aws cloudformation deploy \
  --template-file "$(dirname "$0")/infrastructure/template.yaml" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides "${PARAMS[@]}" \
  --capabilities CAPABILITY_IAM

# Fetch outputs
DATA=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --output json)
S3_BUCKET=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="S3Bucket") | .OutputValue')
LAMBDA_URL=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="LambdaURL") | .OutputValue')
DIST_ID=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="CloudFrontDistributionId") | .OutputValue')
DIST_DOMAIN=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="WebsiteURL") | .OutputValue' | cut -d'/' -f3)

echo ""
echo "Stack:    $STACK_NAME"
echo "Bucket:   $S3_BUCKET"
echo "API:      $LAMBDA_URL"
echo "CDN:      $DIST_DOMAIN"

# Build
echo ""
echo "=== Building ==="
cd "$(dirname "$0")/frontend"
VITE_LAMBDA_URL="$LAMBDA_URL" VITE_HCAPTCHA_SITEKEY="$HCAPTCHA_SITEKEY" npm run build
cd "$(dirname "$0")"

# Upload
echo "=== Uploading to S3 ==="
aws s3 sync frontend/dist/ "s3://$S3_BUCKET/" --delete

# Invalidate CloudFront
echo "=== Invalidating CloudFront: $DIST_ID ==="
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --output text

echo ""
echo "=== Done: https://$DIST_DOMAIN ==="
