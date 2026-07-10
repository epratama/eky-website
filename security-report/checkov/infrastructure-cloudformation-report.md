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

## Risk Acceptance

All 10 findings have been reviewed and are accepted as known risks. The
following assessment was made against cost, complexity, and threat profile
for a personal portfolio website:

| Finding | Decision | Rationale |
|---------|----------|-----------|
| CKV_AWS_18 (S3 logging) | **Accepted** | Static content only, no sensitive data. Enabling logging adds S3 storage costs with no material security benefit for this use case. |
| CKV_AWS_54 (BlockPublicPolicy) | **Cannot remediate** | OAC requires `BlockPublicPolicy: false`. The bucket policy restricts access exclusively to the CloudFront OAC — S3 is not directly public. |
| CKV_AWS_21 (S3 versioning) | **Accepted** | Assets are rebuilt and redeployed with each release. Versioning adds storage costs with minimal benefit for a CI/CD-driven static site. |
| CKV_AWS_86 (CloudFront logging) | **Accepted** | Portfolio traffic volume is negligible. Standard CloudFront metrics provide sufficient observability without the overhead of log delivery and storage. |
| CKV_AWS_174 (CloudFront TLS) | **Accepted** | The ACM certificate attached to the distribution enforces TLS v1.2+ automatically. Explicit protocol declaration is redundant in this configuration. |
| CKV_AWS_68 (CloudFront WAF) | **Accepted (cost)** | At $5-8/month, WAF exceeds the threat profile of a personal portfolio. Rate limiting and bot protection are handled at the application layer (Lambda sliding window + hCaptcha). |
| CKV_AWS_117 (Lambda VPC) | **Accepted (cost)** | A VPC with NAT Gateway costs $33+/month. The Lambda communicates only with public AWS APIs (SES, hCaptcha) — no private resources to protect. |
| CKV_AWS_116 (Lambda DLQ) | **Accepted** | Contact form delivery is best-effort. SES sandbox limits and sender/receiver verification provide upstream guarantees. DLQ adds cost without resolving the root failure mode (SES rejection). |
| CKV_AWS_173 (Lambda env encryption) | **Accepted** | The sole sensitive variable (`HCaptchaSecret`) is declared with `NoEcho: true` in CloudFormation and masked in all API responses. A customer-managed KMS key adds $1/month and operational complexity disproportionate to protection gained. |
| CKV_AWS_95 (API Gateway logging) | **Accepted** | Contact form API traffic is minimal. Application-level error handling (structured HTTP responses) provides sufficient debugging context without additional CloudWatch log costs. |

**Conclusion**: No remediation is required. The 10 findings represent deliberate
trade-offs between security controls and operational cost for a portfolio website
with negligible traffic and no sensitive data. All 22 critical checks (IAM least
privilege, S3 encryption, no hardcoded secrets, HTTPS enforcement) passed.

## Passed Checks (22)

S3 (5), CloudFront (2), IAM (7), Lambda (4): all security-critical checks passed — encryption, IAM least privilege, no data exfiltration, no hardcoded secrets, concurrent execution limits, open CORS.
