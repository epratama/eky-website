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
  *) exit 0 ;;
esac
MOCK
  chmod +x "$MOCK_DIR/aws"

  cat > "$MOCK_DIR/jq" << 'MOCK'
#!/bin/bash
filter="${2:-$1}"
cat > /dev/null  # consume stdin (JSON data)
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
echo "mock build ok"
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
    green "stack not found → creates new"
  else
    red "wrong message" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 2: Stack exists, full deploy flow
echo ""
echo "--- Stack exists → deploy ---"
setup_mock_env
set_mock_defaults
export MOCK_DOMAIN=""
# 4 newlines: sender (accept), recipient (accept), secret (empty), domain (empty)
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

# Test 4a: Cert helper — auto-request with "y"
echo ""
echo "--- Cert helper (auto-request) ---"
setup_mock_env
set_mock_defaults
export MOCK_DOMAIN=""
export MOCK_CERT_LIST=""
# 6 lines: sender, recipient, secret, domain, cert(empty), y
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1 (no cert yet)" "exited 0"
else
  if echo "$output" | grep -q "Searching for existing certificate"; then
    green "auto-requests cert and shows DNS records"
  else
    red "missing cert request output" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 4b: Cert helper — manual
echo ""
echo "--- Cert helper (manual) ---"
setup_mock_env
set_mock_defaults
export MOCK_DOMAIN=""
export MOCK_CERT_LIST=""
# cert empty then n at request prompt
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n\nn\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1" "exited 0"
else
  if echo "$output" | grep -q "Request one manually:"; then
    green "shows manual cert request instructions"
  else
    red "missing manual instructions" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 4c: Auto-detect existing issued cert
echo ""
echo "--- Auto-detect issued cert ---"
setup_mock_env
set_mock_defaults
export MOCK_DOMAIN=""
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tISSUED'
# 4 lines: sender, recipient, secret, domain (cert auto-detected, skips cert prompt)
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "Using existing certificate"; then
    green "auto-detects and reuses issued cert"
  else
    red "did not reuse cert" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 4d: Pending validation cert
echo ""
echo "--- Pending validation cert ---"
setup_mock_env
set_mock_defaults
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tPENDING_VALIDATION'
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

echo ""
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
