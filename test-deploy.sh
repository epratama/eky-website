#!/bin/bash
# test-deploy.sh — smoke tests for deploy.sh
# Usage: ./test-deploy.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"
PASS=0
FAIL=0

green() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
red()   { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

setup_mock_env() {
  MOCK_DIR=$(mktemp -d)
  export PATH="$MOCK_DIR:$PATH"
  trap "rm -rf $MOCK_DIR" EXIT

  cat > "$MOCK_DIR/aws" << 'MOCK'
#!/bin/bash
case "$2" in
  describe-stacks)
    if [ "$MOCK_CF_FAIL" = "true" ]; then
      echo "mock: stack not found" >&2
      exit 1
    fi
    echo "ok"
    ;;
  deploy|sync|cloudfront)
    echo "mock ok"
    ;;
  list-certificates)
    echo "$MOCK_CERT_LIST"
    ;;
  describe-certificate|request-certificate)
    echo ""
    ;;
  list-hosted-zones)
    echo "$MOCK_ZONES"
    ;;
  list-resource-record-sets)
    if echo "$*" | grep -q "www"; then echo "$MOCK_WWW_DNS"; else echo "$MOCK_ROOT_DNS"; fi
    ;;
  change-resource-record-sets)
    echo "mock route53 ok"
    ;;
  *) exit 0 ;;
esac
MOCK
  chmod +x "$MOCK_DIR/aws"

  cat > "$MOCK_DIR/jq" << 'MOCK'
#!/bin/bash
filter="${2:-$1}"
cat > /dev/null
case "$filter" in
  *S3Bucket*)               echo "$MOCK_S3" ;;
  *LambdaURL*)              echo "$MOCK_API" ;;
  *CloudFrontDistributionId*) echo "$MOCK_DIST" ;;
  *WebsiteURL*)             echo "$MOCK_CDN" ;;
  *SenderEmail*)            echo "$MOCK_SENDER" ;;
  *RecipientEmail*)         echo "$MOCK_RECIPIENT" ;;
  *HCaptchaSiteKey*)        echo "$MOCK_SITEKEY" ;;
  *DomainName*)             echo "$MOCK_DOMAIN" ;;
  *CertificateArn*)         echo "$MOCK_CERT" ;;
  *)                        echo "" ;;
esac
MOCK
  chmod +x "$MOCK_DIR/jq"

  cat > "$MOCK_DIR/npm" << 'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$MOCK_DIR/npm"
}

set_mock_defaults() {
  export MOCK_CF_FAIL=false
  export MOCK_S3=bucket
  export MOCK_API=https://api.test
  export MOCK_DIST=E123ABC
  export MOCK_CDN=https://test.cloudfront.net
  export MOCK_SENDER=s@t.com
  export MOCK_RECIPIENT=r@t.com
  export MOCK_SITEKEY=abc
  export MOCK_DOMAIN=""
  export MOCK_CERT=""
  export MOCK_CERT_LIST=""
  export MOCK_ZONES=""
  export MOCK_ROOT_DNS=""
  export MOCK_WWW_DNS=""
}

# --- Tests ---
echo "=== deploy.sh tests ==="

# Test 1: Stack not found
echo ""
echo "--- Stack not found ---"
setup_mock_env
export MOCK_CF_FAIL=true
if output=$(echo "" | bash "$DEPLOY_SCRIPT" no-such-stack 2>&1); then
  red "should exit 1" "exited 0"
else
  if echo "$output" | grep -q "does not exist"; then
    green "stack not found -> creates new"
  else
    red "wrong message" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 2: Stack exists, no domain, full deploy
echo ""
echo "--- Stack exists -> deploy ---"
setup_mock_env
set_mock_defaults
export MOCK_DOMAIN=""
if output=$(printf '\n\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "Stack 'test-stack' exists"; then
    green "shows config and deploys"
  else
    red "missing config display" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 3: Missing deps
echo ""
echo "--- Missing dependencies ---"
MOCK_DIR=$(mktemp -d)
PATH="$MOCK_DIR:/usr/bin:/bin" output=$(bash "$DEPLOY_SCRIPT" test 2>&1) || true
if echo "$output" | grep -qi "missing"; then
  green "warns about missing deps"
else
  red "no dep warning" "$output"
fi
rm -rf "$MOCK_DIR"

# Test 4: Auto-detect issued cert + deploy
echo ""
echo "--- Auto-detect issued cert ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tISSUED'
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "Found issued certificate"; then
    green "auto-detects and uses issued cert"
  else
    red "did not find cert" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 5: Pending cert -> exits with DNS records
echo ""
echo "--- Pending cert -> exit ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=$'arn:abc\tPENDING_VALIDATION'
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1" "exited 0"
else
  if echo "$output" | grep -q "pending validation"; then
    green "shows DNS records and exits for pending cert"
  else
    red "did not handle pending cert" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 6: No cert found -> request new
echo ""
echo "--- No cert -> request new ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=""
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n\ny\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1 (requested new cert)" "exited 0"
else
  if echo "$output" | grep -q "Requesting certificate"; then
    green "requests new cert when none found"
  else
    red "did not request cert" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 7: No cert -> decline request -> blocked
echo ""
echo "--- No cert -> decline -> blocked ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=""
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n\nn\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1" "exited 0"
else
  if echo "$output" | grep -q "Request one manually"; then
    green "shows manual instructions and exits when cert declined"
  else
    red "wrong message" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 8: Route53 records already correct
echo ""
echo "--- Route53 records already correct ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tISSUED'
export MOCK_ZONES=$'/hostedzone/Z123\texample.com.'
export MOCK_DOMAIN="example.com"
export MOCK_ROOT_DNS="test.cloudfront.net."
export MOCK_WWW_DNS="test.cloudfront.net."
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "already correct"; then
    green "detects existing records, skips upsert"
  else
    red "did not skip" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 9: Route53 records need update
echo ""
echo "--- Route53 records updated ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tISSUED'
export MOCK_ZONES=$'/hostedzone/Z123\texample.com.'
export MOCK_DOMAIN="example.com"
export MOCK_ROOT_DNS="old.cloudfront.net."
export MOCK_WWW_DNS=""
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "Route53 records updated"; then
    green "upserts records when outdated/missing"
  else
    red "did not update" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 10: Non-Route53 domain
echo ""
echo "--- Non-Route53 domain ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tISSUED'
export MOCK_ZONES=""
export MOCK_DOMAIN="example.com"
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "not found in Route53"; then
    green "shows manual DNS instructions for non-Route53 domain"
  else
    red "missing manual instructions" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

echo ""
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
