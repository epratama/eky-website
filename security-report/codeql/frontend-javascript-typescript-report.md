# CodeQL Security Scan — JavaScript/TypeScript

- **Language**: JavaScript/TypeScript
- **Source path**: `./frontend`
- **Scan date**: 2025-07-10
- **Query suite**: `codeql/javascript-queries:codeql-suites/javascript-security-extended.qls`
- **Queries run**: 105

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
| 1 | MEDIUM | CWE-209 | `frontend/src/components/ContactForm.jsx:92` | `err.message` exposed to users |
| 2 | LOW | CWE-352 | `ContactForm.jsx:72` | No CSRF token (mitigated by hCaptcha) |
| 3 | LOW | Test key fallback | `ContactForm.jsx:25` | hCaptcha test sitekey `||` fallback in production code |
| 4 | LOW | Unvalidated URL | `Education.jsx:62-63` | `cert.url` rendered without protocol validation |

All 4 findings addressed and fixed.
