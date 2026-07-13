# AWS SSO Auth Check — Design (v2)

## Problem

`deploy.sh` has no AWS authentication pre-check. Users fill in all interactive
prompts (sender email, recipient, hCaptcha, domain, cert) only to have the
script fail with an obscure AWS CLI error because their SSO session expired.

## Scope

Add a `check_aws_auth` function called immediately after dependency checks, before
any user interaction. If unauthenticated, run `aws sso login` (opens browser)
or show manual instructions.

3 files changed. No new dependencies.

## Design

### Behavior Matrix

| State | What Happens |
|-------|-------------|
| `SKIP_AWS_AUTH=1` | Returns immediately (CI/CD) |
| Authenticated | Prints IAM ARN, continues |
| SSO session expired | Runs `aws sso login` (opens browser) |
| Browser doesn't open | Shows manual `aws sso login` command + SSO start URL |
| No AWS config at all | Shows `aws configure sso` + `aws configure` instructions |

### Code (deploy.sh)

Insert after line 18 (closing `fi` of dependency checks), before `# Load saved config`:

```bash
check_aws_auth() {
  [ "${SKIP_AWS_AUTH:-}" = "1" ] && return 0
  local PROFILE="${AWS_PROFILE:-default}"
  local PROFILE_FLAG=""
  [ "$PROFILE" != "default" ] && PROFILE_FLAG="--profile $PROFILE"

  if aws sts get-caller-identity $PROFILE_FLAG --no-cli-pager > /dev/null 2>&1; then
    local ARN=$(aws sts get-caller-identity $PROFILE_FLAG --no-cli-pager --query 'Arn' --output text 2>/dev/null)
    echo "AWS: authenticated as $ARN"
    return 0
  fi

  echo ""
  echo "=== AWS authentication required ==="
  local SSO_URL=$(aws configure get sso_start_url $PROFILE_FLAG 2>/dev/null || echo "")
  if [ -n "$SSO_URL" ]; then
    echo "SSO session expired. Opening browser for login..."
    if aws sso login $PROFILE_FLAG --no-cli-pager 2>&1; then
      echo "AWS SSO login successful."
      return 0
    fi
    echo ""
    echo "Browser didn't open? Run manually:"
    echo "  aws sso login $PROFILE_FLAG"
    echo "  SSO start URL: $SSO_URL"
    exit 1
  fi

  echo "No AWS credentials found. Set up authentication:"
  echo ""
  echo "  For SSO:"
  echo "    aws configure sso"
  echo "    aws sso login"
  echo ""
  echo "  For IAM access key:"
  echo "    aws configure"
  echo ""
  exit 1
}

check_aws_auth
```

### Tests (7)

| # | Test | Scenario |
|---|------|----------|
| 1 | `SKIP_AWS_AUTH=1` — skips | CI/CD skip path |
| 2 | `sts` succeeds — prints ARN | Already authenticated |
| 3 | `sts` fails, SSO config present — `sso login` succeeds | SSO refresh flow |
| 4 | `sts` fails, SSO config present — `sso login` fails | Browser fallback, exit 1 |
| 5 | `sts` fails, no SSO config — setup guide | First-time setup, exit 1 |
| 6 | `AWS_PROFILE=myprofile` — profile flag passed | Named profile respect |
| 7 | IAM creds (non-SSO) works — `sso login` NOT called | Don't suggest SSO for IAM users |

### Design Decisions

- **`SKIP_AWS_AUTH=1` instead of `CI=true`:** Explicit opt-in, not tied to a generic CI variable
- **`--profile` derived from `AWS_PROFILE`:** Standard AWS convention, no custom env var
- **`local` variables:** Clean scope within function
- **`exit 1` on failure:** Hard stop — no point continuing without auth

### Audit Results

| Audit | Verdict |
|-------|---------|
| Security | PASS — 0 findings |
| DevOps | PASS — 0 findings |
| Code | PASS — 0 findings |
| Spec | PASS — 0 findings |
| TDD | PASS — 7 tests cover all paths |

All 5 audits green on v2.
