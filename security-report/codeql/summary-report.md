# CodeQL Security Scan — Summary

**Date:** 2026-07-12 | **Tool:** CodeQL 2.26.0

## Results

| Language | Path | Critical | High | Medium | Low | Status |
|----------|------|----------|------|--------|-----|--------|
| Python | `./backend` | 0 | 0 | 0 | 0 | ✅ PASS |
| JavaScript | `./frontend` | 0 | 0 | 0 | 2 | ✅ PASS |

## Top Issues

No critical, high, or medium findings across any language.

**2 Low** — `js/shell-command-injection-from-environment` in test code (`App.test.jsx:78,85`):
- `execSync` for GTM build test and cleanup — controlled paths, not user input
- **False positives.** No action needed.

## Reports

- [Python report](backend-python-report.md)
- [JavaScript report](frontend-javascript-typescript-report.md)

## Verdict

**PASS** — 0 actionable findings across Python and JavaScript.
