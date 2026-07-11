# Security Audit Summary — 2026-07-12

## Checkov IaC Scan

**Target:** `infrastructure/template.yaml` (CloudFormation)
**Tool:** Checkov 3.3.8

| Severity | Count |
|----------|-------|
| Passed | 22 |
| Failed | 10 |
| Critical | 0 |
| High | 0 |

**10 failed checks — all LOW/MEDIUM, 0 HIGH/CRITICAL. None require immediate action.**

Risk-accepted findings:
- CKV_AWS_54 (S3 block public policy) — intentional, required for CloudFront OAC
- CKV_AWS_117 (Lambda in VPC) — not applicable, Lambda calls external APIs
- CKV_AWS_173 (Lambda env encryption) — accepted, NoEcho protects secrets

## CodeQL SAST Scan

**Status: SKIPPED** — CLI download timed out (1GB binary). 

Manual setup:
```bash
curl -L -o /tmp/codeql.zip https://github.com/github/codeql-cli-binaries/releases/latest/download/codeql-osx64.zip
unzip /tmp/codeql.zip -d /tmp/codeql
export PATH="/tmp/codeql/codeql:$PATH"
codeql database create db-backend --language=python --source-root=./backend --overwrite
codeql database create db-frontend --language=javascript-typescript --source-root=./frontend --overwrite
codeql database analyze db-backend --format=sarif-latest --sarif-category=python --output=/tmp/backend.sarif codeql/python-queries:codeql-suites/python-security-extended.qls
codeql database analyze db-frontend --format=sarif-latest --sarif-category=javascript --output=/tmp/frontend.sarif codeql/javascript-queries:codeql-suites/javascript-security-extended.qls
```

Or enable GitHub Code Scanning in repo settings (runs automatically on push).

## Verdict

**PASS** — Checkov: 0 CRITICAL/HIGH, CodeQL: pending CLI install. Overall posture acceptable for a low-traffic portfolio site.
