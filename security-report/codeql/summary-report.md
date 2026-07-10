# CodeQL Security Scan — Summary

**Date**: 2025-07-10 (re-scan)
**Project**: eky-website

## Aggregated Results

| Language | Path | Queries | Critical | High | Medium | Low | Status |
|----------|------|---------|----------|------|--------|-----|--------|
| Python | `./backend` | 52 | 0 | 0 | 0 | 0 | PASS |
| JavaScript/TypeScript | `./frontend` | 105 | 0 | 0 | 0 | 0 | PASS |
| **Total** | | **157** | **0** | **0** | **0** | **0** | **ALL PASS** |

## Per-Language Reports

- [Python](backend-python-report.md)
- [JavaScript/TypeScript](frontend-javascript-typescript-report.md)

## SARIF Outputs

- [Python SARIF](python-codeql.sarif)
- [JavaScript SARIF](javascript-codeql.sarif)

## Historical Issues (all fixed)

All previous manual findings (6 items) have been addressed and verified:

| # | Severity | File:Line | Issue | Fix |
|---|----------|-----------|-------|-----|
| 1 | MEDIUM | `ContactForm.jsx:92` | `err.message` exposed to users | Replaced with generic message + `console.error` |
| 2 | MEDIUM | `backend/lambda.py:52` | X-Forwarded-For fallback spoofable | Use `requestContext.sourceIp` primarily |
| 3 | LOW | `lambda.py:68` | `mobile` not CR/LF stripped | Applied `re.sub(r"[\r\n\t]")` |
| 4 | LOW | `ContactForm.jsx:25` | Test sitekey fallback | Removed `||` fallback, use `import.meta.env` directly |
| 5 | LOW | `Education.jsx:62-63` | Unvalidated URL rendering | Added `startsWith('https://')` check |
| 6 | LOW | `lambda.py:22,37-45` | `rate_store` unbounded growth | Documented limitation, acceptable for warm-Lambda |

See [full audit report](2025-07-09-security-audit.md) for complete details including fix history, TDD coverage, and re-audit results.
