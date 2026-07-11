#!/bin/bash
# deploy.sh — create/update stack + build + upload + invalidate
# Usage: ./deploy.sh <stack-name>
set -e

STACK_NAME="${1:?Usage: ./deploy.sh <stack-name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Load saved config
[ -f "$SCRIPT_DIR/.env" ] && . "$SCRIPT_DIR/.env"

HCAPTCHA_SITEKEY="e1d21a02-d3c8-4d2e-aee0-7e3671820d2a"
GTM_ID="${GTM_ID:-}"
UPSTASH_REDIS_URL="${UPSTASH_REDIS_URL:-}"
UPSTASH_REDIS_TOKEN="${UPSTASH_REDIS_TOKEN:-}"

# Check if stack exists, fetch current values
STACK_EXISTS=false
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1; then
  STACK_EXISTS=true
  DATA=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --output json 2>/dev/null)
  EXISTING_SENDER=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="SenderEmail") | .ParameterValue' 2>/dev/null)
  EXISTING_RECIPIENT=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="RecipientEmail") | .ParameterValue' 2>/dev/null)
  EXISTING_SITEKEY=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="HCaptchaSiteKey") | .ParameterValue' 2>/dev/null)
  EXISTING_DOMAIN=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="DomainName") | .ParameterValue' 2>/dev/null)
  EXISTING_CERT=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="CertificateArn") | .ParameterValue' 2>/dev/null)
  echo "Stack '$STACK_NAME' exists. Current config:"
  echo "  Sender:     $EXISTING_SENDER"
  echo "  Recipient:  $EXISTING_RECIPIENT"
  echo "  SiteKey:    $EXISTING_SITEKEY"
  [ -n "$EXISTING_DOMAIN" ] && echo "  Domain:     $EXISTING_DOMAIN"
  echo "  SiteKey now: $HCAPTCHA_SITEKEY"
  [ -n "$GTM_ID" ] && echo "  GTM ID:     $GTM_ID" || echo "  GTM:        (not set)"
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
if [ -z "$UPSTASH_REDIS_URL" ] && [ -t 0 ]; then
  read -p "Upstash Redis URL: " UPSTASH_REDIS_URL
fi
if [ -z "$UPSTASH_REDIS_TOKEN" ] && [ -t 0 ]; then
  read -s -p "Upstash Redis token: " UPSTASH_REDIS_TOKEN
  echo ""
fi
if [ -t 0 ]; then
  read -p "Google Analytics ID (${GTM_ID:-}, leave empty to skip): " GTM_INPUT
  GTM_ID="${GTM_INPUT:-$GTM_ID}"
  # Persist for next run
  if [ -n "$GTM_ID" ]; then
    if grep -q "^GTM_ID=" "$SCRIPT_DIR/.env" 2>/dev/null; then
      sed -i '' "s/^GTM_ID=.*/GTM_ID=$GTM_ID/" "$SCRIPT_DIR/.env"
    else
      echo "GTM_ID=$GTM_ID" >> "$SCRIPT_DIR/.env"
    fi
  fi
  if [ -n "$UPSTASH_REDIS_URL" ]; then
    if grep -q "^UPSTASH_REDIS_URL=" "$SCRIPT_DIR/.env" 2>/dev/null; then
      sed -i '' "s|^UPSTASH_REDIS_URL=.*|UPSTASH_REDIS_URL=$UPSTASH_REDIS_URL|" "$SCRIPT_DIR/.env"
    else
      echo "UPSTASH_REDIS_URL=$UPSTASH_REDIS_URL" >> "$SCRIPT_DIR/.env"
    fi
  fi
  if [ -n "$UPSTASH_REDIS_TOKEN" ]; then
    if grep -q "^UPSTASH_REDIS_TOKEN=" "$SCRIPT_DIR/.env" 2>/dev/null; then
      sed -i '' "s|^UPSTASH_REDIS_TOKEN=.*|UPSTASH_REDIS_TOKEN=$UPSTASH_REDIS_TOKEN|" "$SCRIPT_DIR/.env"
    else
      echo "UPSTASH_REDIS_TOKEN=$UPSTASH_REDIS_TOKEN" >> "$SCRIPT_DIR/.env"
    fi
  fi
fi

# ====== SES email verification ======
verify_ses_email() {
  local email="$1"
  local status
  status=$(aws ses get-identity-verification-attributes --identities "$email" \
    --query "VerificationAttributes.\"$email\".VerificationStatus" --output text 2>/dev/null)
  if [ "$status" = "Success" ]; then
    echo "  $email: verified"
    return 0
  fi
  echo "  $email: not verified"
  read -p "  Send verification email to $email? [Y/n]: " VERIFY
  VERIFY=$(echo "${VERIFY:-y}" | tr '[:upper:]' '[:lower:]')
  if [ "$VERIFY" != "y" ]; then
    echo "  WARNING: SES requires verified emails in sandbox mode."
    return 1
  fi
  aws ses verify-email-identity --email-address "$email" > /dev/null 2>&1
  echo "  Verification email sent to $email — check your inbox and click the link."
  echo "  Waiting for verification..."
  for i in $(seq 1 30); do
    sleep 5
    status=$(aws ses get-identity-verification-attributes --identities "$email" \
      --query "VerificationAttributes.\"$email\".VerificationStatus" --output text 2>/dev/null)
    if [ "$status" = "Success" ]; then
      echo "  $email: verified"
      return 0
    fi
    printf "."
  done
  echo ""
  echo "  Verification timed out. Please verify manually and re-run."
  return 1
}

echo ""
echo "=== Checking SES verification ==="
verify_ses_email "$SENDER_EMAIL" || { echo "Sender email not verified. Aborting."; exit 1; }
if [ "$RECIPIENT_EMAIL" != "$SENDER_EMAIL" ]; then
  verify_ses_email "$RECIPIENT_EMAIL" || { echo "Recipient email not verified. Aborting."; exit 1; }
fi

# ====== SES domain setup (SPF, DKIM, DMARC, MAIL FROM) ======
setup_ses_domain() {
  local domain="$1"
  local zone_id="$2"
  echo ""
  echo "=== Setting up SES for $domain ==="

  # 1. Verify domain in SES
  local ses_status
  ses_status=$(aws ses get-identity-verification-attributes --identities "$domain" \
    --query "VerificationAttributes.\"$domain\".VerificationStatus" --output text 2>/dev/null)
  if [ "$ses_status" != "Success" ]; then
    local token
    token=$(aws ses verify-domain-identity --domain "$domain" --query 'VerificationToken' --output text 2>/dev/null)
    if [ -n "$token" ]; then
      echo "  Adding SES domain verification..."
      aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
        --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"_amazonses.$domain\",\"Type\":\"TXT\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"\\\"$token\\\"\"}]}}]}" \
        --output text --no-cli-pager 2>/dev/null
    fi
  else
    echo "  Domain $domain already verified in SES"
  fi

  # 2. SPF record (merge with existing)
  local existing_spf
  existing_spf=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
    --query "ResourceRecordSets[?Name=='$domain.' && Type=='TXT'].ResourceRecords[*].Value" --output text 2>/dev/null)
  local has_spf has_google has_ses
  echo "$existing_spf" | grep -q "v=spf1" && has_spf=true || has_spf=false
  echo "$existing_spf" | grep -q "_spf.google.com" && has_google=true || has_google=false
  echo "$existing_spf" | grep -q "amazonses.com" && has_ses=true || has_ses=false

  if ! $has_ses; then
    local spf_parts=""
    $has_google && spf_parts=" include:_spf.google.com" || true
    spf_parts="$spf_parts include:amazonses.com"
    local spf_value="\"v=spf1$spf_parts ~all\""
    echo "  Adding SPF: $spf_value"

    # Build TXT record preserving existing non-SPF records
    local other_txt
    other_txt=$(echo "$existing_spf" | grep -v "v=spf1" | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')
    local records_json="[{\"Value\":$spf_value}"
    [ -n "$other_txt" ] && records_json+=", {\"Value\":$other_txt}"
    records_json+="]"

    aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
      --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$domain\",\"Type\":\"TXT\",\"TTL\":300,\"ResourceRecords\":$records_json}}]}" \
      --output text --no-cli-pager 2>/dev/null
  else
    echo "  SPF already includes amazonses.com"
  fi

  # 3. DKIM
  local dkim_status
  dkim_status=$(aws ses get-identity-dkim-attributes --identities "$domain" \
    --query "DkimAttributes.\"$domain\".DkimVerificationStatus" --output text 2>/dev/null)
  if [ "$dkim_status" != "Success" ]; then
    local tokens
    tokens=$(aws ses verify-domain-dkim --domain "$domain" --query 'DkimTokens' --output text 2>/dev/null)
    if [ -n "$tokens" ]; then
      echo "  Adding DKIM records..."
      for token in $tokens; do
        aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
          --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"${token}._domainkey.$domain\",\"Type\":\"CNAME\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"${token}.dkim.amazonses.com\"}]}}]}" \
          --output text --no-cli-pager 2>/dev/null
      done
    fi
  else
    echo "  DKIM already enabled for $domain"
  fi

  # 4. MAIL FROM domain
  local mail_from_status
  mail_from_status=$(aws ses get-identity-mail-from-domain-attributes --identities "$domain" \
    --query "MailFromDomainAttributes.\"$domain\".MailFromDomainStatus" --output text 2>/dev/null)
  if [ "$mail_from_status" != "Success" ]; then
    aws ses set-identity-mail-from-domain --identity "$domain" \
      --mail-from-domain "mail.$domain" --behavior-on-mx-failure UseDefaultValue 2>/dev/null
    echo "  Adding MAIL FROM DNS records..."
    aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
      --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"mail.$domain\",\"Type\":\"MX\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"10 feedback-smtp.ap-southeast-2.amazonses.com\"}]}},{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"mail.$domain\",\"Type\":\"TXT\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"\\\"v=spf1 include:amazonses.com ~all\\\"\"}]}}]}" \
      --output text --no-cli-pager 2>/dev/null
  else
    echo "  MAIL FROM already configured for $domain"
  fi

  # 5. DMARC
  local existing_dmarc
  existing_dmarc=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
    --query "ResourceRecordSets[?Name=='_dmarc.$domain.'].ResourceRecords[0].Value" --output text 2>/dev/null)
  if [ -z "$existing_dmarc" ] || [ "$existing_dmarc" = "None" ]; then
    echo "  Adding DMARC record..."
    aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
      --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"_dmarc.$domain\",\"Type\":\"TXT\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"\\\"v=DMARC1; p=none; rua=mailto:$RECIPIENT_EMAIL\\\"\"}]}}]}" \
      --output text --no-cli-pager 2>/dev/null
  else
    echo "  DMARC already configured"
  fi

  echo "  SES domain setup complete for $domain"
}

# ====== Custom domain + cert ======
find_cert_for_domain() {
  local domain="$1"
  echo "Searching for existing certificate for $domain..." >&2
  local certs
  certs=$(aws acm list-certificates \
    --region us-east-1 \
    --certificate-statuses ISSUED PENDING_VALIDATION \
    --query "CertificateSummaryList[?DomainName=='$domain'].[CertificateArn,DomainName,Status]" \
    --output text 2>/dev/null)
  if [ -n "$certs" ]; then
    local arn
    arn=$(echo "$certs" | awk '{print $1}')
    cert_status=$(echo "$certs" | awk '{print $NF}')
    if [ "$cert_status" = "ISSUED" ]; then
      echo "$arn"
      return 0
    elif [ "$cert_status" = "PENDING_VALIDATION" ]; then
      echo "Certificate is still pending validation: $arn"
      echo ""
      echo "DNS validation records:"
      aws acm describe-certificate \
        --certificate-arn "$arn" \
        --query 'Certificate.DomainValidationOptions[*].{Domain:DomainName,Name:ResourceRecord.Name,Type:ResourceRecord.Type,Value:ResourceRecord.Value}' \
        --region us-east-1 \
        --output table
      echo ""
      echo "Add these CNAMEs at your DNS provider and wait for validation, then re-run."
      return 2
    fi
  fi
  return 1
}

request_cert() {
  local domain="$1"
  echo "Requesting certificate for $domain and www.$domain..."
  ARN=$(aws acm request-certificate \
    --domain-name "$domain" \
    --subject-alternative-names "www.$domain" \
    --validation-method DNS \
    --region us-east-1 \
    --query 'CertificateArn' --output text)
  echo "Certificate ARN: $ARN"
  echo ""
  echo "DNS validation records (add these at your DNS provider):"
  aws acm describe-certificate \
    --certificate-arn "$ARN" \
    --query 'Certificate.DomainValidationOptions[*].{Domain:DomainName,Name:ResourceRecord.Name,Type:ResourceRecord.Type,Value:ResourceRecord.Value}' \
    --region us-east-1 \
    --output table
  echo ""
  echo "After adding these CNAMEs and waiting 5-10 min for validation, re-run:"
  echo "  ./deploy.sh $STACK_NAME"
  echo "  Domain name: $domain"
  echo "  Certificate ARN: $ARN"
  exit 1
}

# Custom domain prompt
CERT_ARN=""
if [ "$STACK_EXISTS" = true ] && [ -n "$EXISTING_DOMAIN" ]; then
  read -p "Custom domain [$EXISTING_DOMAIN]: " DOMAIN_NAME
  DOMAIN_NAME="${DOMAIN_NAME:-$EXISTING_DOMAIN}"
else
  echo "Custom domain (optional — leave empty to skip):"
  read -p "Domain name: " DOMAIN_NAME
fi

if [ -n "$DOMAIN_NAME" ]; then
  set +e
  FOUND_CERT=$(find_cert_for_domain "$DOMAIN_NAME" 2>&1)
  FIND_EXIT=$?
  set -e
  if [ "$FIND_EXIT" -eq 2 ]; then
    echo "$FOUND_CERT"
    exit 1
  fi
  if [ "$FIND_EXIT" -eq 0 ]; then
    CERT_ARN=$(echo "$FOUND_CERT" | tail -1)
    echo "Found issued certificate: $CERT_ARN"
    echo "Using existing certificate."
  else
    echo "${FOUND_CERT:-No existing certificate found.}"
    if [ "$STACK_EXISTS" = true ] && [ -n "$EXISTING_CERT" ]; then
      read -p "Certificate ARN [$EXISTING_CERT]: " CERT_ARN
      CERT_ARN="${CERT_ARN:-$EXISTING_CERT}"
    else
      read -p "Certificate ARN (leave empty to request new): " CERT_ARN
    fi
    if [ -z "$CERT_ARN" ]; then
      read -p "Request certificate now? [Y/n]: " REQUEST_CERT
      REQUEST_CERT=$(echo "${REQUEST_CERT:-y}" | tr '[:upper:]' '[:lower:]')
      if [ "$REQUEST_CERT" = "y" ]; then
        request_cert "$DOMAIN_NAME"
      else
        echo "Request one manually:"
        echo "  aws acm request-certificate --domain-name $DOMAIN_NAME --subject-alternative-names www.$DOMAIN_NAME --validation-method DNS --region us-east-1"
        exit 1
      fi
    fi
  fi
fi

# Build parameter overrides
PARAMS=()
PARAMS+=(ParameterKey=HCaptchaSiteKey,ParameterValue="$HCAPTCHA_SITEKEY")
PARAMS+=(ParameterKey=SenderEmail,ParameterValue="$SENDER_EMAIL")
PARAMS+=(ParameterKey=RecipientEmail,ParameterValue="$RECIPIENT_EMAIL")
if [ -n "$HCAPTCHA_SECRET" ]; then
  PARAMS+=(ParameterKey=HCaptchaSecret,ParameterValue="$HCAPTCHA_SECRET")
else
  PARAMS+=(ParameterKey=HCaptchaSecret,UsePreviousValue=true)
fi
PARAMS+=(ParameterKey=UpstashRedisUrl,ParameterValue="$UPSTASH_REDIS_URL")
PARAMS+=(ParameterKey=UpstashRedisToken,ParameterValue="$UPSTASH_REDIS_TOKEN")

# Validate domain + cert consistency
if [ -n "$DOMAIN_NAME" ] && [ -z "$CERT_ARN" ]; then
  echo ""
  echo "ERROR: Domain name is set but no valid certificate ARN was provided."
  echo "You need an ISSUED ACM certificate in us-east-1 before deploying with a custom domain."
  exit 1
fi
if [ -n "$DOMAIN_NAME" ] && [ -n "$CERT_ARN" ]; then
  PARAMS+=(ParameterKey=DomainName,ParameterValue="$DOMAIN_NAME")
  PARAMS+=(ParameterKey=CertificateArn,ParameterValue="$CERT_ARN")
fi

# Deploy/update stack
echo ""
echo "=== Deploying stack: $STACK_NAME ==="
[ -n "$UPSTASH_REDIS_URL" ] && echo "Upstash URL: configured" || echo "Upstash URL: not set"
if [ "$STACK_EXISTS" = true ]; then
  UPDATE_OUTPUT=$(aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$SCRIPT_DIR/infrastructure/template.yaml" \
    --parameters "${PARAMS[@]}" \
    --capabilities CAPABILITY_IAM \
    --no-cli-pager 2>&1) || UPDATE_EXIT=$?
  echo "$UPDATE_OUTPUT"
  if echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
    echo "No changes needed."
  elif [ "${UPDATE_EXIT:-0}" -ne 0 ]; then
    echo "Update failed, check output above."
    exit 1
  else
    echo "Waiting for update..."
    aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --no-cli-pager 2>&1 || true
  fi
else
  aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$SCRIPT_DIR/infrastructure/template.yaml" \
    --parameters "${PARAMS[@]}" \
    --capabilities CAPABILITY_IAM \
    --no-cli-pager 2>&1
  echo "Waiting for creation..."
  aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --no-cli-pager 2>&1
fi

# Verify params applied
if [ -n "$DOMAIN_NAME" ]; then
  STACK_DOMAIN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
    --query "Stacks[0].Parameters[?ParameterKey=='DomainName'].ParameterValue" --output text 2>/dev/null)
  STACK_CERT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
    --query "Stacks[0].Parameters[?ParameterKey=='CertificateArn'].ParameterValue" --output text 2>/dev/null)
  if [ "$STACK_DOMAIN" != "$DOMAIN_NAME" ] || [ "$STACK_CERT" != "$CERT_ARN" ]; then
    echo ""
    echo "WARNING: Domain/cert params may not have applied correctly."
    echo "  Expected domain: $DOMAIN_NAME, got: $STACK_DOMAIN"
    echo "  Expected cert:   $CERT_ARN, got: $STACK_CERT"
    echo "  Check your hCaptcha secret and re-run."
  fi
fi

# Fetch outputs
DATA=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --output json)
S3_BUCKET=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="S3Bucket") | .OutputValue')
LAMBDA_URL=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="LambdaURL") | .OutputValue')
DIST_ID=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="CloudFrontDistributionId") | .OutputValue')
DIST_DOMAIN=$(echo "$DATA" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="WebsiteURL") | .OutputValue' | cut -d'/' -f3)
DOMAIN=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="DomainName") | .ParameterValue' 2>/dev/null)

echo ""
echo "Stack:    $STACK_NAME"
echo "Bucket:   $S3_BUCKET"
echo "API:      $LAMBDA_URL"
echo "CDN:      $DIST_DOMAIN"

# Build
echo ""
echo "=== Building ==="
cd "$SCRIPT_DIR/frontend"
if [ -n "$GTM_ID" ]; then
  VITE_GTM_ID="$GTM_ID" VITE_LAMBDA_URL="$LAMBDA_URL" VITE_HCAPTCHA_SITEKEY="$HCAPTCHA_SITEKEY" npm run build
else
  VITE_LAMBDA_URL="$LAMBDA_URL" VITE_HCAPTCHA_SITEKEY="$HCAPTCHA_SITEKEY" npm run build
fi
cd "$SCRIPT_DIR"

# Upload
echo "=== Uploading to S3 ==="
aws s3 sync frontend/dist/ "s3://$S3_BUCKET/" --delete

# Invalidate CloudFront
echo "=== Invalidating CloudFront: $DIST_ID ==="
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --output text

echo ""
if [ -n "$DOMAIN" ]; then
  echo "=== Configuring DNS ==="
  ZONE_ID=$(aws route53 list-hosted-zones --output json 2>/dev/null \
    | jq -r --arg d "$DOMAIN." '.HostedZones[] | select(.Name==$d) | .Id' \
    | sed 's|/hostedzone/||')
  if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "None" ]; then
    echo "Route53 zone found: $ZONE_ID"

    # Set up SES domain (SPF, DKIM, DMARC, MAIL FROM) for sender domain
    SENDER_DOMAIN=$(echo "$SENDER_EMAIL" | cut -d'@' -f2)
    if [ -n "$SENDER_DOMAIN" ] && [ "$SENDER_DOMAIN" != "gmail.com" ] && [ "$SENDER_DOMAIN" != "yahoo.com" ] && [ "$SENDER_DOMAIN" != "outlook.com" ]; then
      setup_ses_domain "$SENDER_DOMAIN" "$ZONE_ID"
    fi

    EXISTING_ROOT=$(aws route53 list-resource-record-sets \
      --hosted-zone-id "$ZONE_ID" \
      --query "ResourceRecordSets[?Name=='$DOMAIN.' && Type=='A'].AliasTarget.DNSName" \
      --output text 2>/dev/null)
    EXISTING_WWW=$(aws route53 list-resource-record-sets \
      --hosted-zone-id "$ZONE_ID" \
      --query "ResourceRecordSets[?Name=='www.$DOMAIN.' && Type=='A'].AliasTarget.DNSName" \
      --output text 2>/dev/null)

    NEED_ROOT=false
    NEED_WWW=false
    if [ "$EXISTING_ROOT" != "$DIST_DOMAIN." ]; then
      NEED_ROOT=true
      echo "  root: $DOMAIN → $DIST_DOMAIN"
    else
      echo "  root: already points to $DIST_DOMAIN"
    fi
    if [ "$EXISTING_WWW" != "$DIST_DOMAIN." ]; then
      NEED_WWW=true
      echo "  www:  www.$DOMAIN → $DIST_DOMAIN"
    else
      echo "  www:  already points to $DIST_DOMAIN"
    fi

    if $NEED_ROOT || $NEED_WWW; then
      CHANGES="["
      if $NEED_ROOT; then
        CHANGES+="{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$DOMAIN\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"Z2FDTNDATAQYW2\",\"DNSName\":\"$DIST_DOMAIN\",\"EvaluateTargetHealth\":false}}}"
      fi
      if $NEED_ROOT && $NEED_WWW; then
        CHANGES+=","
      fi
      if $NEED_WWW; then
        CHANGES+="{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"www.$DOMAIN\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"Z2FDTNDATAQYW2\",\"DNSName\":\"$DIST_DOMAIN\",\"EvaluateTargetHealth\":false}}}"
      fi
      CHANGES+="]"
      aws route53 change-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --change-batch "{\"Changes\": $CHANGES}" \
        --output text --no-cli-pager
      echo "Route53 records updated."
    else
      echo "All records already correct — nothing to do."
    fi
  else
    echo "Domain not found in Route53. Add DNS records at your provider:"
    echo ""
    echo "  Type   Name                        Value"
    echo "  ----   ----                        -----"
    echo "  A      $DOMAIN              ALIAS  $DIST_DOMAIN"
    echo "  A      www.$DOMAIN          ALIAS  $DIST_DOMAIN"
    echo ""
    echo "  If your provider doesn't support ALIAS/ANAME at the root:"
    echo "    - Redirect $DOMAIN to www.$DOMAIN"
    echo "    - Create a CNAME for www.$DOMAIN → $DIST_DOMAIN"
  fi
  echo ""
  echo "=== Done: https://$DOMAIN ==="
else
  echo "=== Done: https://$DIST_DOMAIN ==="
fi
