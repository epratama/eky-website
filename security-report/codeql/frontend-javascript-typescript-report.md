# CodeQL Scan — JavaScript/TypeScript (frontend)

**Date:** 2026-07-12 | **Tool:** CodeQL 2.26.0
**Source:** `./frontend` (7 JS files)
**Query suite:** `codeql/javascript-queries:codeql-suites/javascript-security-extended.qls`

## Findings

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 2 |
| Warning | 0 |

### Low (2)

| Rule | File:Line | Issue |
|------|-----------|-------|
| `js/shell-command-injection-from-environment` | `src/__tests__/App.test.jsx:78` | execSync runs Vite build for GTM test |
| `js/shell-command-injection-from-environment` | `src/__tests__/App.test.jsx:85` | execSync removes test directory |

Both are **false positives** — `execSync` is used in test code with controlled paths (`resolve(__dirname, ...)` + `process.env`), not user input. No action needed.

## Verdict

**PASS** — 0 critical/high/medium. 2 low false positives in test code.
