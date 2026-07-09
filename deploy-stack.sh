#!/bin/bash
# deploy-stack.sh — create or update CloudFormation stack
# Usage: ./deploy-stack.sh <stack-name> <hcaptcha-secret> <recipient-email> <sender-email>
set -e

STACK_NAME="${1:?Usage: ./deploy-stack.sh <stack-name> <hcaptcha-secret> <recipient-email> <sender-email>}"
HCAPTCHA_SECRET="${2:?Missing hCaptcha secret}"
RECIPIENT_EMAIL="${3:?Missing recipient email}"
SENDER_EMAIL="${4:?Missing sender email}"
HCAPTCHA_SITEKEY="e1d21a02-d3c8-4d2e-aee0-7e3671820d2a"

command -v aws > /dev/null 2>&1 || { echo "Error: aws CLI required"; exit 1; }

aws cloudformation deploy \
  --template-file infrastructure/template.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    HCaptchaSecret="$HCAPTCHA_SECRET" \
    HCaptchaSiteKey="$HCAPTCHA_SITEKEY" \
    RecipientEmail="$RECIPIENT_EMAIL" \
    SenderEmail="$SENDER_EMAIL" \
  --capabilities CAPABILITY_IAM

echo ""
echo "=== Stack outputs ==="
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table
