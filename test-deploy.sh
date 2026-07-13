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
    cat << JSONEOF
{"Stacks":[{"Parameters":[
  {"ParameterKey":"SenderEmail","ParameterValue":"${MOCK_SENDER}"},
  {"ParameterKey":"RecipientEmail","ParameterValue":"${MOCK_RECIPIENT}"},
  {"ParameterKey":"HCaptchaSiteKey","ParameterValue":"${MOCK_SITEKEY}"},
  {"ParameterKey":"HCaptchaSecret","ParameterValue":"****"},
  {"ParameterKey":"DomainName","ParameterValue":"${MOCK_DOMAIN}"},
  {"ParameterKey":"CertificateArn","ParameterValue":"${MOCK_CERT}"},
  {"ParameterKey":"UpstashRedisUrl","ParameterValue":"****"},
  {"ParameterKey":"UpstashRedisToken","ParameterValue":"****"}
],"Outputs":[
  {"OutputKey":"S3Bucket","OutputValue":"${MOCK_S3}"},
  {"OutputKey":"LambdaURL","OutputValue":"${MOCK_API}"},
  {"OutputKey":"CloudFrontDistributionId","OutputValue":"${MOCK_DIST}"},
  {"OutputKey":"WebsiteURL","OutputValue":"${MOCK_CDN}"}
]}]}
JSONEOF
    ;;
  deploy|sync|cloudfront|update-stack|create-stack)
    echo "mock ok"
    ;;
  list-certificates)
    echo "$MOCK_CERT_LIST"
    ;;
  describe-certificate|request-certificate)
    echo ""
    ;;
  list-hosted-zones)
    if [ -n "$MOCK_ZONES_ID" ]; then
      echo "{\"HostedZones\":[{\"Id\":\"/hostedzone/$MOCK_ZONES_ID\",\"Name\":\"$MOCK_ZONES_NAME.\",\"CallerReference\":\"x\",\"Config\":{\"PrivateZone\":false},\"ResourceRecordSetCount\":14}]}"
    else
      echo "{\"HostedZones\":[]}"
    fi
    ;;
  list-resource-record-sets)
    if echo "$*" | grep -q "www"; then echo "$MOCK_WWW_DNS"; else echo "$MOCK_ROOT_DNS"; fi
    ;;
  change-resource-record-sets)
    echo "mock route53 ok"
    ;;
  get-identity-verification-attributes)
    if [ -f /tmp/mock-ses-polled ]; then
      echo "Success"
    else
      touch /tmp/mock-ses-polled
      echo "$MOCK_SES_STATUS"
    fi
    ;; 
  verify-email-identity)
    echo ""
    ;;
  verify-domain-identity|verify-domain-dkim)
    echo ""
    ;;
  get-identity-dkim-attributes|get-identity-mail-from-domain-attributes)
    echo "Success"
    ;;
  set-identity-mail-from-domain)
    echo ""
    ;;
  get-caller-identity)
    echo "$MOCK_STS_OUTPUT"
    [ "$MOCK_STS_EXIT" = "fail" ] && exit 1 || exit 0
    ;;
  login)
    if [ "$MOCK_SSO_EXIT" = "fail" ]; then
      echo "SSO login failed" >&2
      exit 1
    fi
    echo "SSO login successful" >&2
    exit 0
    ;;
  get)
    if echo "$*" | grep -q "sso_start_url"; then
      echo "${MOCK_SSO_URL:-}"
    fi
    exit 0
    ;;
  *) exit 0 ;; 
esac
MOCK
  chmod +x "$MOCK_DIR/aws"

  cat > "$MOCK_DIR/npm" << 'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$MOCK_DIR/npm"
}

set_mock_defaults() {
  rm -f /tmp/mock-ses-polled
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
  export MOCK_ZONES_ID=""
  export MOCK_ZONES_NAME=""
  export MOCK_ROOT_DNS=""
  export MOCK_WWW_DNS=""
  export MOCK_SES_STATUS="Success"
  export MOCK_STS_OUTPUT=""
  export MOCK_STS_EXIT="success"
  export MOCK_SSO_EXIT="success"
  export MOCK_SSO_URL=""
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
export MOCK_ZONES_ID="Z123"
export MOCK_ZONES_NAME="example.com"
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
export MOCK_ZONES_ID="Z123"
export MOCK_ZONES_NAME="example.com"
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
export MOCK_ZONES_ID=""
export MOCK_ZONES_NAME=""
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

# Test 11: SES already verified
echo ""
echo "--- SES already verified ---"
setup_mock_env
set_mock_defaults
export MOCK_SES_STATUS="Success"
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "s@t.com: verified"; then
    green "skips SES when email already verified"
  else
    red "SES check not shown" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 12: SES not verified -> user declines
echo ""
echo "--- SES not verified -> decline ---"
setup_mock_env
set_mock_defaults
export MOCK_SES_STATUS="Pending"
export MOCK_DOMAIN=""
# inputs: sender, recipient, secret (empty), decline verify, domain (empty)
if output=$(printf 's@t.com\nr@t.com\n\nn\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1" "exited 0"
else
  if echo "$output" | grep -q "not verified"; then
    green "aborts when SES verification declined"
  else
    red "did not abort" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 13: SES not verified -> user verifies
echo ""
echo "--- SES not verified -> verify ---"
rm -f /tmp/mock-ses-polled
setup_mock_env
set_mock_defaults
export MOCK_SES_STATUS="Pending"
export MOCK_DOMAIN=""
# inputs: sender, recipient, secret, y (verify), domain (empty)
if output=$(printf 's@t.com\nr@t.com\n\ny\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "verified"; then
    green "verifies SES email and continues"
  else
    red "verification failed" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
rm -f /tmp/mock-ses-polled
trap - EXIT

# --- AWS Auth Check Tests ---

# Test 14: SKIP_AWS_AUTH=1
echo ""
echo "--- SKIP_AWS_AUTH=1 ---"
setup_mock_env
set_mock_defaults
export SKIP_AWS_AUTH=1
export MOCK_DOMAIN=""  # skip domain prompts
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "authenticated"; then
    red "should skip auth" "auth check ran"
  else
    green "skips auth check when SKIP_AWS_AUTH=1"
  fi
else
  red "deploy failed" "$output"
fi
unset SKIP_AWS_AUTH
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 15: Already authenticated
echo ""
echo "--- Already authenticated ---"
setup_mock_env
set_mock_defaults
export MOCK_STS_EXIT="success"
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tISSUED'
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "authenticated as"; then
    green "prints authenticated message"
  else
    red "no auth message" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 16: SSO login succeeds
echo ""
echo "--- SSO login succeeds ---"
setup_mock_env
set_mock_defaults
export MOCK_STS_EXIT="fail"
export MOCK_SSO_URL="https://test.awsapps.com/start"
export MOCK_SSO_EXIT="success"
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "SSO login successful"; then
    green "SSO login succeeds, deploy continues"
  else
    red "SSO success not detected" "$output"
  fi
else
  status=$?
  if [ $status -eq 1 ] && echo "$output" | grep -q "SSO"; then
    red "SSO login should succeed" "$output"
  else
    red "deploy failed" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 17: SSO login fails — manual fallback
echo ""
echo "--- SSO login fails ---"
setup_mock_env
set_mock_defaults
export MOCK_STS_EXIT="fail"
export MOCK_SSO_URL="https://test.awsapps.com/start"
export MOCK_SSO_EXIT="fail"
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1" "exited 0"
else
  status=$?
  if [ $status -eq 1 ] && echo "$output" | grep -q "Browser didn't open"; then
    green "shows manual login instructions"
  else
    red "wrong message" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 18: No AWS config — setup guide
echo ""
echo "--- No AWS config ---"
setup_mock_env
set_mock_defaults
export MOCK_STS_EXIT="fail"
export MOCK_SSO_URL=""
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  red "should exit 1" "exited 0"
else
  status=$?
  if [ $status -eq 1 ] && echo "$output" | grep -q "aws configure"; then
    green "shows setup guide (both SSO and IAM)"
  else
    red "wrong message" "$output"
  fi
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 19: AWS_PROFILE respected
echo ""
echo "--- AWS_PROFILE respected ---"
setup_mock_env
set_mock_defaults
export MOCK_STS_EXIT="fail"
export MOCK_SSO_URL="https://test.awsapps.com/start"
export MOCK_SSO_EXIT="success"
export MOCK_DOMAIN=""
export AWS_PROFILE="myprofile"
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  green "deploy continues with profile"
else
  red "deploy failed" "$output"
fi
unset AWS_PROFILE
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

# Test 20: IAM creds — no SSO suggestion
echo ""
echo "--- IAM creds skip SSO ---"
setup_mock_env
set_mock_defaults
export MOCK_STS_EXIT="success"
export MOCK_SSO_URL="https://test.awsapps.com/start"  # SSO configured
export MOCK_CERT_LIST=$'arn:aws:acm:us-east-1:123:cert/abc\tISSUED'
export MOCK_DOMAIN=""
if output=$(printf 's@t.com\nr@t.com\n\n\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "authenticated as" && ! echo "$output" | grep -q "SSO"; then
    green "authenticated, skips SSO suggestion"
  else
    red "SSO suggested for IAM user" "$output"
  fi
else
  red "deploy failed" "$output"
fi
rm -rf "$MOCK_DIR" 2>/dev/null || true
trap - EXIT

echo ""
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
