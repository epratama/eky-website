# CodeQL Security Scan — Python

- **Language**: Python
- **Source path**: `./backend`
- **Scan date**: 2025-07-10
- **Query suite**: `codeql/python-queries:codeql-suites/python-security-extended.qls`
- **Queries run**: 52

## Findings

| Severity | Count |
|----------|-------|
| Error | 0 |
| Warning | 0 |
| Recommendation | 0 |

**Verdict**: PASS (0 automated findings)

## Manual Review Findings

| # | Severity | Rule | File:Line | Description |
|---|----------|------|-----------|-------------|
| 1 | MEDIUM | Rate-limit bypass | `backend/lambda.py:52` | `x-forwarded-for` fallback for IP source is spoofable |
| 2 | LOW | Memory leak | `backend/lambda.py:22,37-45` | `rate_store` dict never prunes stale keys |
| 3 | INFO | Missing sanitization | `backend/lambda.py:68` | `mobile` field not stripped of CR/LF |

All 3 manual findings addressed and fixed.
