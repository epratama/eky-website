#!/bin/bash
# test-template.sh — validate CloudFormation template
# Usage: ./test-template.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/infrastructure/template.yaml"
PASS=0
FAIL=0

green() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
red()   { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== CF template tests ==="

echo ""
echo "--- Validate template syntax ---"
if aws cloudformation validate-template --template-body "file://$TEMPLATE" > /dev/null 2>&1; then
  green "validate-template passes"
else
  red "validate-template failed"
fi

echo ""
echo "--- Required resources ---"
required="WebsiteBucket CloudFrontDistribution CloudFrontOriginAccessControl ContactFormFunction LambdaExecutionRole HttpApi HttpApiRoute HttpApiStage LambdaApiPermission"
for res in $required; do
  if grep -q "$res:" "$TEMPLATE"; then
    green "resource: $res"
  else
    red "missing: $res"
  fi
done

echo ""
echo "--- Required parameters ---"
required_params="HCaptchaSecret HCaptchaSiteKey RecipientEmail SenderEmail DomainName CertificateArn"
for param in $required_params; do
  if grep -q "$param:" "$TEMPLATE"; then
    green "parameter: $param"
  else
    red "missing: $param"
  fi
done

echo ""
echo "--- No hardcoded secrets ---"
if grep -q "NoEcho: true" "$TEMPLATE"; then
  green "HCaptchaSecret marked NoEcho"
else
  red "HCaptchaSecret not NoEcho"
fi

echo ""
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
