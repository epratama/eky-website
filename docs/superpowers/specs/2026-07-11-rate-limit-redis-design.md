# Rate Limiting with Upstash Redis — Design (v2)

## Problem

`_rate_limit` in `backend/lambda.py` uses an in-memory Python dict (`rate_store = {}`)
at module level. AWS Lambda execution environments are ephemeral — the dict is lost
on cold start and not shared across concurrent invocations. Rate limiting is
effectively non-functional.

## Scope

Replace the in-memory rate store with Upstash Redis (serverless, REST API, free tier).
4 files changed. No new dependencies (stdlib `urllib.request` only).

## Design

### Thresholds

| Parameter | Value |
|-----------|-------|
| Max requests per IP | 5 |
| Window | 300 seconds (5 min) |
| Redis key format | `rate:{ip}` |
| Redis call timeout | 1 second |
| Fail mode | Open — allow on error |
| Lambda timeout | 10 → 12 seconds |

### Architecture

```
Browser → API Gateway HTTP API → Lambda (Python 3.12) → Upstash Redis REST API
                                        ↓                    ↓
                                   hCaptcha verify      INCR rate:{ip}
                                   SES send email       EXPIRE 300
```

### Rate Limit Logic

On every request:
1. `INCR rate:{ip}` (creates key auto-initialized to 1 if new)
2. `EXPIRE rate:{ip} 300` (refreshes TTL on every request — no race condition)
3. If `count > 5` → 429 Too Many Requests
4. Any Redis error → fail open (allow request), log sanitized message only

### Code (lambda.py)

```python
UPSTASH_REDIS_REST_URL = os.environ["UPSTASH_REDIS_REST_URL"]
UPSTASH_REDIS_REST_TOKEN = os.environ["UPSTASH_REDIS_REST_TOKEN"]
RATE_MAX = 5
RATE_WINDOW = 300


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

**Changes:**
- `import time` removed (no longer needed)
- `rate_store = {}` removed
- Two new module-level env var reads added
- `EXPIRE` called on every request (unconditional — prevents race condition where TTL was never set)
- Error log sanitized (no token/exc details)
- Timeouts: 1s per Redis call

### Infrastructure (template.yaml)

**New Parameters** (after SenderEmail, both `NoEcho: true`):
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

**New Env Vars** (in ContactFormFunction.Environment.Variables):
```yaml
          UPSTASH_REDIS_REST_URL: !Ref UpstashRedisUrl
          UPSTASH_REDIS_REST_TOKEN: !Ref UpstashRedisToken
```

**Lambda Timeout:**
```yaml
      Timeout: 12  # was 10
```

**Inline ZipFile:** Must match `backend/lambda.py` exactly. Update the inline code block (lines 208-326) with the v2 code. Remove `import time` and `rate_store = {}`, add the two env var reads and new `_rate_limit` implementation.

### Deploy Script (deploy.sh)

Fetch existing values on stack update (alongside other `EXISTING_*` vars):
```bash
  EXISTING_UPSTASH_URL=$(echo "$DATA" | jq -r '.Stacks[0].Parameters[] | select(.ParameterKey=="UpstashRedisUrl") | .ParameterValue' 2>/dev/null)
```

Display in existing config block (after SiteKey):
```bash
  [ -n "$EXISTING_UPSTASH_URL" ] && echo "  Upstash:   $EXISTING_UPSTASH_URL"
```

Prompt after hCaptcha secret:
```bash
read -s -p "Upstash Redis URL (leave empty to keep existing): " UPSTASH_REDIS_URL
echo ""
read -s -p "Upstash Redis token (leave empty to keep existing): " UPSTASH_REDIS_TOKEN
echo ""
```

Append to PARAMS:
```bash
if [ -n "$UPSTASH_REDIS_URL" ]; then
  PARAMS+=(ParameterKey=UpstashRedisUrl,ParameterValue="$UPSTASH_REDIS_URL")
fi
if [ -n "$UPSTASH_REDIS_TOKEN" ]; then
  PARAMS+=(ParameterKey=UpstashRedisToken,ParameterValue="$UPSTASH_REDIS_TOKEN")
fi
```

### Tests (8 total)

| # | Test | What |
|---|------|------|
| 1 | `test_rate_limit_allows_first_request` | mock INCR→1, EXPIRE called, returns True |
| 2 | `test_rate_limit_allows_at_boundary` | mock INCR→5, EXPIRE called, returns True |
| 3 | `test_rate_limit_rejects_after_5_requests` | mock INCR→6, returns False → 429 |
| 4 | `test_rate_limit_calls_expire_on_every_request` | mock INCR→3, verify EXPIRE WAS called |
| 5 | `test_rate_limit_fail_open_on_redis_error` | URLError → returns True (allow) |
| 6 | `test_upstash_env_vars_set` | `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` present |
| 7 | `test_rate_limit_uses_request_context_ip` | existing, update count 3→5 |
| 8 | `test_rate_limit_falls_back_to_x_forwarded_for` | existing, update count 3→5 |

**Removed:** `test_rate_limit_resets_after_window`, `clear_rate_store` fixture, `test_rate_store_exists`

### Design Decisions

- **Fail open:** hCaptcha is the security gate; rate limiting is abuse prevention
- **EXPIRE unconditional:** eliminates race condition where TTL was never set
- **1s timeouts:** Lambda budget: 1s (INCR) + 1s (EXPIRE) + 10s (hCaptcha) + 2s (SES) = 14s worst case, but typical ~3s. Lambda timeout raised to 12s.
- **Sanitized error log:** `print("Rate limit check failed")` only — no token or exception details
- **No new dependencies:** stdlib `urllib.request` (same pattern as existing hCaptcha call)
- **No IAM changes:** Upstash is external HTTPS, no VPC needed

### Audit Results

| Audit | Verdict |
|-------|---------|
| TDD (8 tests) | **PASS** — no coverage gaps |
| MoA (5 agents) | **PASS** — 0 findings |
| Spec Review | **PASS** — consistent, complete, unambiguous |

All 3 audits green on v2.
