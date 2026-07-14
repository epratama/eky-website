#!/bin/bash
PASS=0; FAIL=0
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
  sts)
    echo "$MOCK_STS_OUTPUT"
    [ "$MOCK_STS_EXIT" = "fail" ] && exit 1 || exit 0
    ;;
  sso)
    if [ "$MOCK_SSO_EXIT" = "fail" ]; then
      echo "SSO login failed" >&2
      exit 1
    fi
    echo "SSO login successful" >&2
    exit 0
    ;;
  configure)
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
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
setup_mock_env
set_mock_defaults
echo ""
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
