# AWS SSO Auth Check — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pre-flight AWS authentication check to `deploy.sh` — verify `aws sts get-caller-identity` before any user prompts; offer `aws sso login` if session expired.

**Architecture:** New `check_aws_auth()` function inserted after dependency checks, before prompts. Respects `AWS_PROFILE`. Supports `SKIP_AWS_AUTH=1` for CI/CD. 7 new deploy tests.

**Tech Stack:** Bash, AWS CLI (sts, sso, configure), mock-based testing

## Global Constraints

- Respect `AWS_PROFILE` env var for named profiles
- `SKIP_AWS_AUTH=1` skips the check entirely (CI/CD)
- `local` variable scope within function
- `set -e` compatible — use `if` conditions to catch errors
- Insert at line 19 of deploy.sh (after dep checks, before `# Load saved config`)
- Mock all new `aws` subcommands (`sts`, `sso`, `configure`) in test-deploy.sh

## Spec Reference

`docs/superpowers/specs/2026-07-12-aws-sso-auth-check-design.md` (v2, 5 audits pass)

---

### Task 1: Update test-deploy.sh (TDD — RED phase)

**Files:**
- Modify: `test-deploy.sh`

- [ ] **Step 1: Add mock cases for new AWS subcommands**

In the `aws` mock (after the existing case statement entries), add before the `*) exit 0 ;;` line:

```bash
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
    if [ "$3" = "get" ] && [ "$4" = "sso_start_url" ]; then
      echo "${MOCK_SSO_URL:-}"
    fi
    exit 0
    ;;
```

- [ ] **Step 2: Add defaults to `set_mock_defaults`**

After the existing defaults, add:

```bash
  export MOCK_STS_OUTPUT=""
  export MOCK_STS_EXIT="success"
  export MOCK_SSO_EXIT="success"
  export MOCK_SSO_URL=""
```

- [ ] **Step 3: Add 7 new tests**

After the existing test cases, before the summary section, add:

```bash
# --- AWS Auth Check Tests ---

# Test 14: SKIP_AWS_AUTH=1
echo ""
echo "--- SKIP_AWS_AUTH=1 ---"
setup_mock_env
set_mock_defaults
export SKIP_AWS_AUTH=1
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "authenticated" || echo "$output" | grep -q "auth"; then
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
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
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
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
  if echo "$output" | grep -q "SSO login successful"; then
    green "SSO login succeeds, deploy continues"
  else
    red "SSO success not detected" "$output"
  fi
else
  status=$?
  if [ $status -eq 1 ] && echo "$output" | grep -q "SSO login"; then
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
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
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
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
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
export AWS_PROFILE="myprofile"
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
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
if output=$(printf 's@t.com\nr@t.com\n\nexample.com\n' | bash "$DEPLOY_SCRIPT" test-stack 2>&1); then
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
```

- [ ] **Step 4: Run tests to verify they FAIL (RED)**

```bash
bash test-deploy.sh
```
Expected: 7 new tests FAIL with "deploy failed" or wrong messages — the `check_aws_auth` function doesn't exist yet.

---

### Task 2: Implement check_aws_auth in deploy.sh (GREEN phase)

**Files:**
- Modify: `deploy.sh`

- [ ] **Step 1: Insert function after line 18**

After the dependency check `fi` (line 18), before `# Load saved config` (line 20), insert:

```bash
# Check AWS auth
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

- [ ] **Step 2: Run deploy tests to verify they PASS**

```bash
bash test-deploy.sh
```
Expected: all 20 tests PASS (13 original + 7 new).

- [ ] **Step 3: Run all other tests**

```bash
python3 -m pytest backend/test_lambda.py -q
npm -C frontend test
bash test-template.sh
```
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add deploy.sh test-deploy.sh
git commit -m "feat: add AWS SSO auth pre-check to deploy.sh (7 tests)"
```

---

### Task 3: Update README (Deploy pipeline description)

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add auth check to Full Pipeline table**

In the Pre-flight row, add mention of AWS auth check:

```diff
-| **Pre-flight** | Checks `aws`, `jq`, `npm` installed. Queries CloudFormation for existing stack config. |
+| **Pre-flight** | Checks `aws`, `jq`, `npm` installed. Verifies AWS authentication (SSO or IAM). Queries CloudFormation for existing stack config. |
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add AWS auth check to deploy pipeline description"
```

---

## Failure Protocol

At ANY step that fails:

1. **STOP.** Do not continue.
2. Invoke `superpowers:systematic-debugging` to find root cause
3. Apply fix
4. Re-run the failed step
5. Resume from where you stopped
