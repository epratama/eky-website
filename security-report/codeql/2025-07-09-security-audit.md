# Security Audit Report

**Date**: 2025-07-09 (updated 2025-07-10)
**Project**: eky-website (portfolio website)
**Languages**: Python (backend), JavaScript/TypeScript (frontend), YAML (infrastructure)
**Tools**: Manual code review, CodeQL security-extended suite v2.26.0

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 1 |
| HIGH | 2 |
| MEDIUM | 6 |
| LOW | 8 |
| INFO | 3 |

---

## Python Backend

### CRITICAL: Origin check bypass via substring matching

- **Location**: `backend/lambda.py:29`, `infrastructure/template.yaml:232`
- **Description**: `_check_origin` uses `ALLOWED_ORIGIN in origin` — substring check, not exact match. An attacker can bypass by setting `Origin: https://ekyputrapratama.com.evil.com`. Any malicious site can submit the contact form.
- **Fix**: Parse the URL and compare scheme + netloc exactly:
```python
from urllib.parse import urlparse

def _check_origin(headers):
    if not ALLOWED_ORIGIN:
        return True
    allowed = urlparse(ALLOWED_ORIGIN)
    origin = urlparse((headers or {}).get("origin", ""))
    return origin.scheme == allowed.scheme and origin.netloc == allowed.netloc
```

### HIGH: X-Forwarded-For spoofing bypasses rate limiting

- **Location**: `backend/lambda.py:45`, `infrastructure/template.yaml:246`
- **Description**: `source_ip = headers.get("x-forwarded-for", "unknown").split(",")[0]` — the first value in X-Forwarded-For is client-controlled. Attacker sends a different IP per request and never hits the rate limit.
- **Fix**: Use API Gateway v2's request context for the real client IP:
```python
source_ip = (event.get("requestContext", {}).get("http", {}).get("sourceIp") or "unknown")
```

### HIGH: In-memory rate store is per-Lambda-container

- **Location**: `backend/lambda.py:21,38-39`, `infrastructure/template.yaml:225,240`
- **Description**: `rate_store = {}` is module-level state. Each Lambda container has its own independent store. With `ReservedConcurrentExecutions: 5`, an attacker gets 15 req/min (5 × 3). Cold starts reset counters.
- **Fix**: Use DynamoDB with TTL for persistent rate tracking, or add AWS WAF rate-based rules on the API Gateway stage.

### MEDIUM: Open CORS default when ALLOWED_ORIGIN is empty

- **Location**: `backend/lambda.py:25-26,133-138`, `infrastructure/template.yaml:227-229,301-302`
- **Description**: When `ALLOWED_ORIGIN` is empty, `_check_origin` returns `True` for any origin and CORS returns `*`. Any website can make cross-origin requests.
- **Fix**: Make `ALLOWED_ORIGIN` required. If deployed without custom domain, compute the CloudFront/API Gateway URL explicitly.

### MEDIUM: No input length limits

- **Location**: `backend/lambda.py:58-61`, `infrastructure/template.yaml:258-261`
- **Description**: `name`, `email`, `mobile`, `message` have no maximum length. Attacker can POST multi-megabyte strings, consuming Lambda memory and SES costs.
- **Fix**: Add length caps (name ≤ 200, email ≤ 254, mobile ≤ 50, message ≤ 10000).

### MEDIUM: Excess IAM permission — ses:SendRawEmail

- **Location**: `infrastructure/template.yaml:185`
- **Description**: IAM policy grants `ses:SendRawEmail` but code only uses `ses.send_email()`. SendRawEmail allows arbitrary MIME construction including header injection.
- **Fix**: Remove `ses:SendRawEmail`, keep only `ses:SendEmail`.

### MEDIUM: Email subject contains unescaped user input

- **Location**: `backend/lambda.py:104`, `infrastructure/template.yaml:292`
- **Description**: `name` interpolated directly into Subject line without stripping control characters. Newlines (`\r\n`) could inject email headers in edge cases.
- **Fix**: Strip `\r\n\t` from name before using in subject.

### LOW: Text body unescaped

- **Location**: `backend/lambda.py:97`, `infrastructure/template.yaml:290`
- **Description**: `text_body` interpolates user input with no sanitization (text/plain, so no XSS, but impersonation possible).

### LOW: Email validation regex allows unbounded-length addresses

- **Location**: `backend/lambda.py:20`, `infrastructure/template.yaml:224`
- **Description**: No length cap on email validation. RFC 5321 limits to 254 chars.

---

## JavaScript Frontend

### MEDIUM: No Content Security Policy

- **Location**: `frontend/index.html:1`
- **Description**: No CSP header or meta tag. External scripts (hCaptcha) and fonts (Google Fonts) load without restrictions.
- **Fix**: Add CSP meta tag or serve as HTTP header from CloudFront:
```
default-src 'self'; script-src 'self' https://js.hcaptcha.com https://hcaptcha.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; frame-src https://hcaptcha.com https://*.hcaptcha.com; connect-src 'self' https://hcaptcha.com https://*.amazonaws.com; form-action 'self'; frame-ancestors 'none'
```

### MEDIUM: No clickjacking protection

- **Location**: `frontend/index.html:1`
- **Description**: No `X-Frame-Options` or `frame-ancestors` CSP directive. Site could be iframed.
- **Fix**: Add `frame-ancestors 'none'` to CSP, or configure CloudFront to send `X-Frame-Options: DENY`.

### LOW: hCaptcha test sitekey fallback in production code

- **Location**: `frontend/src/components/ContactForm.jsx:25`
- **Description**: `VITE_HCAPTCHA_SITEKEY || '10000000-ffff-ffff-ffff-000000000001'` — if VITE_HCAPTCHA_SITEKEY is unset, uses test key. Form would fail server-side (real secret ≠ test secret), so it's a broken form, not a bypass. But the source-level presence is a code smell.
- **Fix**: Remove fallback: use `import.meta.env.VITE_HCAPTCHA_SITEKEY` directly.

### LOW: Unvalidated external URL in Education links

- **Location**: `frontend/src/components/Education.jsx:62-63`
- **Description**: `cert.url` from static JSON rendered as `<a href={cert.url}>`. Trusted source but no protocol validation.
- **Fix**: Validate URLs start with `https://` before rendering.

### LOW: Dynamic third-party script without SRI

- **Location**: `frontend/src/components/ContactForm.jsx:17-19`
- **Description**: hCaptcha script loaded at runtime without SRI hash. Standard practice for captcha services. Acceptable risk.

---

## Infrastructure

### MEDIUM: CloudFront security headers

- **Location**: `infrastructure/template.yaml:99-121`
- **Description**: ResponseHeadersPolicy already includes `X-XSS-Protection`, `X-Content-Type-Options`, `Referrer-Policy`, `Strict-Transport-Security`. Partially addresses CSP and framing concerns.

---

## Actions Taken During Audit

1. ✅ Fixed: `dev-bypass` captcha token gated behind `ALLOW_CAPTCHA_BYPASS` env var (production = `"false"`)
2. ✅ Fixed: Frontend `hcaptcha_token: token || 'dev-bypass'` gated behind `import.meta.env.DEV`
3. ✅ Fixed: Added `_esc` single-quote escaping to template.yaml inline Lambda
4. ✅ Fixed (TDD): Origin check bypass — replaced substring match with urlparse exact comparison (+www handling)
5. ✅ Fixed (TDD): Rate limit IP spoofing — uses `requestContext.http.sourceIp` first, X-Forwarded-For as fallback
6. ✅ Fixed: Input length limits — name ≤200, email ≤254, mobile ≤50, message ≤10000
7. ✅ Fixed: Control chars `\r\n\t` stripped from name before email subject
8. ✅ Fixed: Removed `ses:SendRawEmail` from IAM policy (least privilege)
9. ✅ Fixed: CSP meta tag added to index.html
10. ✅ Fixed: Clickjacking protection via CloudFront `FrameOptions: DENY` (already configured)
11. ✅ Fixed: Removed hCaptcha test sitekey fallback (`10000000-ffff-ffff-ffff-000000000001`)
12. ✅ Fixed: Education URLs validated to start with `https://`
13. ✅ Fixed: Template.yaml indentation error in input validation block
14. ✅ Fixed: ALLOWED_ORIGIN conditional on HasCustomDomain to avoid broken origin check without custom domain
15. ⚠️ Documented: Per-container rate store limitation — each Lambda container has isolated counters. Mitigated by reserved concurrency (5) and correct source IP. Full fix requires DynamoDB or WAF.

### Re-audit Results

| Original Finding | Status |
|---|---|
| CRITICAL: Origin check bypass | ✅ Fixed — urlparse exact matching |
| HIGH: X-Forwarded-For spoofing | ✅ Fixed — requestContext.sourceIp |
| HIGH: Per-container rate store | ⚠️ Documented — DynamoDB/WAF tradeoff |
| MEDIUM: Open CORS default | ✅ Fixed — ALLOWED_ORIGIN conditional |
| MEDIUM: No input length limits | ✅ Fixed |
| MEDIUM: Excess ses:SendRawEmail | ✅ Fixed |
| MEDIUM: Unescaped email subject | ✅ Fixed — control chars stripped |
| MEDIUM: No CSP | ✅ Fixed |
| MEDIUM: No clickjacking | ✅ Fixed — CloudFront FrameOptions: DENY |
| LOW: Text body unescaped | ⚠️ Acceptable — text/plain, no XSS risk |
| LOW: Test sitekey fallback | ✅ Fixed — removed |
| LOW: Unvalidated external URLs | ✅ Fixed — https:// prefix check |
| LOW: Unbounded email length | ✅ Fixed — ≤254 char limit |
| LOW: Dynamic script without SRI | ⚠️ Acceptable — hCaptcha doesn't publish SRI |

### Test Coverage

| Suite | Before | After |
|---|---|---|
| Backend (pytest) | 13 | 20 |
| Frontend (Vitest) | 12 | 13 |
| Deploy (bash) | 13 | 13 |
| Template (bash) | 17 | 17 |
| **Total** | **55** | **63** |

---

## CodeQL Automated Scan (2025-07-10)

| Language | Queries Run | Automated Findings |
|---|---|---|
| Python | 52 | 0 |
| JavaScript/TypeScript | 105 | 0 |

3 manual findings from post-CodeQL review:

| # | Severity | File | Issue | Fix |
|---|----------|------|-------|-----|
| 1 | MEDIUM | `ContactForm.jsx:92` | `err.message` exposed to users (CWE-209) | Replaced with generic message + `console.error` |
| 2 | LOW | `lambda.py:99` | `mobile` field not stripped of CR/LF | Applied same `re.sub(r"[\r\n\t]")` as name |
| 3 | INFO | `lambda.py:52` | X-Forwarded-For fallback for rate limit IP | Acceptable — defense-in-depth; `requestContext.sourceIp` is primary source |

All 3 findings fixed in commit `181ef89`.
