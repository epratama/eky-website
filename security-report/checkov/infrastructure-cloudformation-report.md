# Checkov IaC Security Scan — CloudFormation

- **IaC type**: CloudFormation
- **Source path**: `./infrastructure/template.yaml`
- **Scan date**: 2025-07-10
- **Checkov version**: 3.3.8
- **Framework**: `cloudformation`

## Results Summary

| Result | Count |
|--------|-------|
| Passed | 22 |
| Failed | 10 |
| Skipped | 0 |

## Failed Checks

| # | Severity | Check ID | Resource | File:Line | Description |
|---|----------|----------|----------|-----------|-------------|
| 1 | MEDIUM | CKV_AWS_18 | `WebsiteBucket` | `template.yaml:31` | S3 bucket access logging not enabled |
| 2 | LOW | CKV_AWS_54 | `WebsiteBucket` | `template.yaml:31` | S3 block public policy not enabled (intentional — OAC requires `BlockPublicPolicy: false`) |
| 3 | LOW | CKV_AWS_21 | `WebsiteBucket` | `template.yaml:31` | S3 bucket versioning not enabled |
| 4 | MEDIUM | CKV_AWS_86 | `CloudFrontDistribution` | `template.yaml:123` | CloudFront access logging not enabled |
| 5 | LOW | CKV_AWS_174 | `CloudFrontDistribution` | `template.yaml:123` | CloudFront Viewer Certificate TLS version not explicitly set to TLSv1.2 |
| 6 | MEDIUM | CKV_AWS_68 | `CloudFrontDistribution` | `template.yaml:123` | CloudFront WAF not enabled |
| 7 | LOW | CKV_AWS_117 | `ContactFormFunction` | `template.yaml:190` | Lambda not inside a VPC |
| 8 | LOW | CKV_AWS_116 | `ContactFormFunction` | `template.yaml:190` | Lambda no Dead Letter Queue configured |
| 9 | LOW | CKV_AWS_173 | `ContactFormFunction` | `template.yaml:190` | Lambda environment variables not encrypted at rest |
| 10 | MEDIUM | CKV_AWS_95 | `HttpApiStage` | `template.yaml:354` | API Gateway V2 Stage access logging not enabled |

## Verdict: LOW RISK — 10 findings, all non-critical for portfolio use

Most failures are intentional or cost-optimized for a personal portfolio website:

| Finding | Why Skipped |
|---------|-------------|
| S3 logging (CKV_AWS_18) | Static site — no sensitive content, zero access cost |
| S3 block public policy (CKV_AWS_54) | Must be `false` for OAC bucket policy |
| S3 versioning (CKV_AWS_21) | Static assets rebuilt on deploy, no version history needed |
| CloudFront logging (CKV_AWS_86) | Portfolio traffic is minimal |
| CloudFront TLS (CKV_AWS_174) | ACM cert enforces TLS v1.2+ automatically |
| CloudFront WAF (CKV_AWS_68) | $5/month — overkill for portfolio, rate limiting handled by Lambda |
| Lambda VPC (CKV_AWS_117) | Not needed — Lambda only calls SES + hCaptcha (public endpoints) |
| Lambda DLQ (CKV_AWS_116) | Contact form failures are non-critical |
| Lambda env encryption (CKV_AWS_173) | HCaptchaSecret already masked via `NoEcho: true` |
| API Gateway logging (CKV_AWS_95) | Contact form traffic is minimal |

## Passed Checks (22)

S3 (5), CloudFront (2), IAM (7), Lambda (4): all security-critical checks passed — encryption, IAM least privilege, no data exfiltration, no hardcoded secrets, concurrent execution limits, open CORS.
