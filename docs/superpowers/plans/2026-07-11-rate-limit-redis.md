# Rate Limiting with Upstash Redis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace broken in-memory `rate_store = {}` in Lambda contact form with Upstash Redis REST API rate limiting (5 req / 300s per IP).

**Architecture:** Lambda calls Upstash REST API via `urllib.request` (same pattern as existing hCaptcha call) to `INCR` + `EXPIRE` Redis keys. New CloudFormation params (NoEcho) for URL and token. No new dependencies, no IAM changes.

**Tech Stack:** Python 3.12, stdlib urllib.request, Upstash Redis REST API, AWS CloudFormation

## Global Constraints

- No new dependencies — `urllib.request` only (same pattern as hCaptcha in existing code)
- Env var names: `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` everywhere
- Rate limit: 5 requests per 300 seconds per IP, fail open on error
- Redis key format: `rate:{ip}`, INCR + EXPIRE both called on every request
- Lambda timeout: 12s (was 10s)
- Redis call timeout: 1 second each
- Error log sanitized: `print("Rate limit check failed")` only, no token/exc details
- `import time` removed, `rate_store = {}` removed
- Template.yaml inline ZipFile code must match backend/lambda.py exactly
- CloudFormation params: `NoEcho: true` for both Upstash params
- deploy.sh: same `read -s` pattern as HCAPTCHA_SECRET, append to PARAMS conditionally

## Spec Reference

`docs/superpowers/specs/2026-07-11-rate-limit-redis-design.md` (v2, 3 audits pass)

---

### Task 1: Backend Lambda + Tests (TDD)

**Files:**
- Modify: `backend/test_lambda.py`
- Modify: `backend/lambda.py`
- Test: `python3 -m pytest backend/test_lambda.py -q`

**Interfaces:**
- Consumes: current `handler._rate_limit` and `handler.rate_store` module attributes
- Produces: `handler._rate_limit(ip)` → `True` (allowed) or `False` (rate limited), `handler` module with `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` env var reads

- [ ] **Step 1: Remove old rate limit fixtures and tests**

Edit `backend/test_lambda.py`:
- Remove `clear_rate_store` fixture (lines 42-44)
- Remove `test_rate_store_exists` (lines 52-53)
- Remove `test_rate_limit_resets_after_window` (lines 129-144)

- [ ] **Step 2: Add new env vars and new rate limit tests**

In `backend/test_lambda.py`, after `os.environ["ALLOW_CAPTCHA_BYPASS"] = "true"` (line 18), add:

```python
os.environ["UPSTASH_REDIS_REST_URL"] = "https://test-upstash.upstash.io"
os.environ["UPSTASH_REDIS_REST_TOKEN"] = "test-token"
```

Replace the entire "# --- Rate limiting ---" section (lines 113-171) with:

```python
# --- Rate limiting ---

class _FakeResponse:
    def __init__(self, data):
        self._data = data
    def read(self):
        return json.dumps(self._data).encode()
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass

def _make_fake_urlopen(incr_result, expire_ok=True):
    def fake_urlopen(req, timeout=None):
        url = req.full_url
        if "/incr/" in url:
            return _FakeResponse({"result": incr_result})
        elif "/expire/" in url:
            if not expire_ok:
                raise OSError("expire failed")
            return _FakeResponse({"result": 1})
        raise OSError("unexpected URL")
    return fake_urlopen


def test_rate_limit_allows_first_request():
    with patch.object(urllib.request, "urlopen", _make_fake_urlopen(1)):
        assert handler._rate_limit("1.2.3.4") is True


def test_rate_limit_allows_at_boundary():
    with patch.object(urllib.request, "urlopen", _make_fake_urlopen(5)):
        assert handler._rate_limit("1.2.3.4") is True


def test_rate_limit_rejects_after_5_requests():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.2.3.4", "origin": "https://ekyputrapratama.com"},
    )
    with patch.object(urllib.request, "urlopen", _make_fake_urlopen(6)):
        resp = handler.handler(event, None)
        body, status = parse_response(resp)
        assert status == HTTPStatus.TOO_MANY_REQUESTS


def test_rate_limit_calls_expire_on_every_request():
    expire_called = [False]

    def tracking_urlopen(req, timeout=None):
        if "/expire/" in req.full_url:
            expire_called[0] = True
            return _FakeResponse({"result": 1})
        return _FakeResponse({"result": 3})

    with patch.object(urllib.request, "urlopen", tracking_urlopen):
        handler._rate_limit("1.2.3.4")
    assert expire_called[0] is True


def test_rate_limit_fail_open_on_redis_error():
    def error_urlopen(req, timeout=None):
        raise OSError("connection refused")

    with patch.object(urllib.request, "urlopen", error_urlopen):
        assert handler._rate_limit("1.2.3.4") is True


def test_upstash_env_vars_set():
    assert os.environ.get("UPSTASH_REDIS_REST_URL") == "https://test-upstash.upstash.io"
    assert os.environ.get("UPSTASH_REDIS_REST_TOKEN") == "test-token"


def test_rate_limit_uses_request_context_ip_not_spoofed_header():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.2.3.4, 10.0.0.1", "origin": "https://ekyputrapratama.com"},
    )
    event["requestContext"] = {"http": {"sourceIp": "5.6.7.8"}}
    with patch.object(urllib.request, "urlopen", _make_fake_urlopen(1)):
        resp = handler.handler(event, None)
        assert parse_response(resp)[1] == HTTPStatus.OK
    with patch.object(urllib.request, "urlopen", _make_fake_urlopen(6)):
        resp = handler.handler(event, None)
        body, status = parse_response(resp)
        assert status == HTTPStatus.TOO_MANY_REQUESTS


def test_rate_limit_falls_back_to_x_forwarded_for():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.1.1.1", "origin": "https://ekyputrapratama.com"},
    )
    with patch.object(urllib.request, "urlopen", _make_fake_urlopen(1)):
        resp = handler.handler(event, None)
        assert parse_response(resp)[1] == HTTPStatus.OK
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
python3 -m pytest backend/test_lambda.py -q
```
Expected: FAIL — `handler` module still has old `_rate_limit`, `handler.rate_store` may be referenced by removed tests' fixture cleanup code, new env vars not yet in lambda.py

- [ ] **Step 4: Update lambda.py**

Edit `backend/lambda.py`:

Remove line 3 (`import time`):

```python
# Before:
import json, os, re, time
# After:
import json, os, re
```

Remove line 23 (`rate_store = {}`).

After line 18 (`ALLOW_CAPTCHA_BYPASS = ...`) add:

```python
UPSTASH_REDIS_REST_URL = os.environ["UPSTASH_REDIS_REST_URL"]
UPSTASH_REDIS_REST_TOKEN = os.environ["UPSTASH_REDIS_REST_TOKEN"]
RATE_MAX = 5
RATE_WINDOW = 300
```

Replace `_rate_limit` function (lines 38-46) with:

```python
def _rate_limit(ip):
    key = f"rate:{ip}"
    try:
        incr_req = urllib.request.Request(
            f"{UPSTASH_REDIS_REST_URL}/incr/{key}",
            method="POST",
            headers={"Authorization": f"Bearer {UPSTASH_REDIS_REST_TOKEN}"},
        )
        with urllib.request.urlopen(incr_req, timeout=1) as resp:
            count = json.loads(resp.read()).get("result", 0)

        expire_req = urllib.request.Request(
            f"{UPSTASH_REDIS_REST_URL}/expire/{key}/{RATE_WINDOW}",
            method="POST",
            headers={"Authorization": f"Bearer {UPSTASH_REDIS_REST_TOKEN}"},
        )
        urllib.request.urlopen(expire_req, timeout=1)

        return count <= RATE_MAX
    except Exception:
        print("Rate limit check failed")
        return True
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
python3 -m pytest backend/test_lambda.py -q
```
Expected: 29 tests, all PASS (2 removed, 5 new + 2 updated = 34 total... actually verify count matches)

**If any test fails:** STOP. Read the failure, fix the test or implementation, re-run.

- [ ] **Step 6: Commit**

```bash
git add backend/lambda.py backend/test_lambda.py
git commit -m "feat: replace in-memory rate_store with Upstash Redis rate limiting

Replaces broken in-memory rate_store dict with Upstash Redis REST API
(INCR + EXPIRE rate:{ip}). 5 req per 300s per IP. Fail open on Redis error.
Removes import time, adds UPSTASH_REDIS_REST_URL/TOKEN env var reads."
```

---

### Task 2: Infrastructure Config

**Files:**
- Modify: `infrastructure/template.yaml`
- Modify: `deploy.sh`

**Interfaces:**
- Consumes: Task 1's updated lambda.py (for inline ZipFile code copy)
- Produces: CloudFormation stack with UpstashRedisUrl, UpstashRedisToken params and env vars; deploy.sh prompts for them

- [ ] **Step 1: Update template.yaml — Parameters**

Add after line 25 (`SenderEmail` param block):

```yaml
  UpstashRedisUrl:
    Type: String
    NoEcho: true
    Description: Upstash Redis REST URL
  UpstashRedisToken:
    Type: String
    NoEcho: true
    Description: Upstash Redis REST token
```

- [ ] **Step 2: Update template.yaml — Lambda timeout**

Edit line 197:
```yaml
      Timeout: 12
```

- [ ] **Step 3: Update template.yaml — Env vars**

After line 206 (`ALLOW_CAPTCHA_BYPASS: "false"`), add:

```yaml
          UPSTASH_REDIS_REST_URL: !Ref UpstashRedisUrl
          UPSTASH_REDIS_REST_TOKEN: !Ref UpstashRedisToken
```

- [ ] **Step 4: Update template.yaml — Inline ZipFile code**

Replace lines 209-326 (the entire inline `ZipFile` block) with the updated lambda code from Task 1.

Read `backend/lambda.py` content, strip comments for compactness (existing inline code uses minified style — remove blank lines and unnecessary whitespace to fit within CloudFormation 4096-byte parameter limit).

The inline code should start with:
```python
import json, os, re
from http import HTTPStatus
from urllib.parse import urlparse
import urllib.request, urllib.parse
import boto3

RECIPIENT_EMAIL = os.environ["RECIPIENT_EMAIL"]
SENDER_EMAIL = os.environ["SENDER_EMAIL"]
HCAPTCHA_SECRET = os.environ["HCAPTCHA_SECRET"]
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "")
DOMAIN_NAME = os.environ.get("DOMAIN_NAME", "")
ALLOW_CAPTCHA_BYPASS = os.environ.get("ALLOW_CAPTCHA_BYPASS", "") == "true"
HCAPTCHA_VERIFY_URL = "https://hcaptcha.com/siteverify"
UPSTASH_REDIS_REST_URL = os.environ["UPSTASH_REDIS_REST_URL"]
UPSTASH_REDIS_REST_TOKEN = os.environ["UPSTASH_REDIS_REST_TOKEN"]
RATE_MAX = 5
RATE_WINDOW = 300
ses = boto3.client("ses")
EMAIL_RE = re.compile(...)
...
```

Full inline code: copy `backend/lambda.py` verbatim, minified to single-line functions where possible (matching existing style).

- [ ] **Step 5: Update deploy.sh — Fetch existing Upstash values**

After line 35 (`EXISTING_CERT=` line), add:

```bash
  EXISTING_UPSTASH_URL=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="UpstashRedisUrl") | .ParameterValue' 2>/dev/null)
```

- [ ] **Step 6: Update deploy.sh — Display in config block**

After line 39 (`echo "  SiteKey..."`), add:

```bash
  [ -n "$EXISTING_UPSTASH_URL" ] && echo "  Upstash:   $EXISTING_UPSTASH_URL"
```

- [ ] **Step 7: Update deploy.sh — Prompt for Upstash credentials**

After line 59 (`echo ""` following hCaptcha secret prompt), add:

```bash
if [ "$STACK_EXISTS" = true ] && [ -n "$EXISTING_UPSTASH_URL" ]; then
  echo "Upstash Redis will remain unchanged unless you enter new values."
fi
read -s -p "Upstash Redis URL (leave empty to keep existing): " UPSTASH_REDIS_URL
echo ""
read -s -p "Upstash Redis token (leave empty to keep existing): " UPSTASH_REDIS_TOKEN
echo ""
```

- [ ] **Step 8: Update deploy.sh — Append to PARAMS**

Before the domain validation block (before line 332), add:

```bash
if [ -n "$UPSTASH_REDIS_URL" ]; then
  PARAMS+=(ParameterKey=UpstashRedisUrl,ParameterValue="$UPSTASH_REDIS_URL")
fi
if [ -n "$UPSTASH_REDIS_TOKEN" ]; then
  PARAMS+=(ParameterKey=UpstashRedisToken,ParameterValue="$UPSTASH_REDIS_TOKEN")
fi
```

- [ ] **Step 9: Verify template.yaml syntax**

```bash
aws cloudformation validate-template --template-body "file://infrastructure/template.yaml"
```
Expected: no errors.

- [ ] **Step 10: Commit**

```bash
git add infrastructure/template.yaml deploy.sh
git commit -m "feat: add Upstash Redis params and env vars to CloudFormation + deploy script"
```

---

### Task 3: Full Test Suite Verification

**Files:**
- Test: backend (pytest), frontend (vitest), deploy (bash), build

- [ ] **Step 1: Run backend tests**

```bash
python3 -m pytest backend/test_lambda.py -q
```
Expected: 34 tests, all PASS.

- [ ] **Step 2: Run frontend tests**

```bash
npm -C frontend test
```
Expected: 15 tests, all PASS.

- [ ] **Step 3: Production build**

```bash
npm -C frontend run build
```
Expected: build succeeds.

- [ ] **Step 4: Commit (if any test file was updated)**

```bash
# Only if needed
git add -A
git commit -m "test: update tests for rate limit changes"
```

---

## Failure Protocol

At ANY step that fails:

1. **STOP.** Do not continue.
2. Invoke `superpowers:systematic-debugging` to find root cause
3. Apply fix
4. Re-run the failed step
5. If the fix changes code written in Tasks 1-2, re-run Task 3 (full test suite)
6. Resume from where you stopped
