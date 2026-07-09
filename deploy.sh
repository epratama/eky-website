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

HCAPTCHA_SITEKEY="e1d21a02-d3c8-4d2e-aee0-7e3671820d2a"

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
fi

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
aws cloudformation deploy \
  --template-file "$SCRIPT_DIR/infrastructure/template.yaml" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides "${PARAMS[@]}" \
  --capabilities CAPABILITY_IAM

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
VITE_LAMBDA_URL="$LAMBDA_URL" VITE_HCAPTCHA_SITEKEY="$HCAPTCHA_SITEKEY" npm run build
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
  ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='$DOMAIN'.]|[0].Id" \
    --output text 2>/dev/null | sed 's|/hostedzone/||')
  if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "None" ]; then
    echo "Route53 zone found: $ZONE_ID"

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
    echo "Domain not found in Route53. Add manually:"
    echo "  $DOMAIN           CNAME  $DIST_DOMAIN"
    echo "  www.$DOMAIN       CNAME  $DIST_DOMAIN"
    if echo "$DOMAIN" | grep -q "\.com$"; then
      echo "  Note: providers that block CNAME at root need ALIAS/ANAME."
    fi
  fi
  echo ""
  echo "=== Done: https://$DOMAIN ==="
else
  echo "=== Done: https://$DIST_DOMAIN ==="
fi
