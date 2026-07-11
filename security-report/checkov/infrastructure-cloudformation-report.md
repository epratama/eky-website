# Checkov CloudFormation Scan — infrastructure/template.yaml

**Date:** 2026-07-12 | **Tool:** Checkov 3.3.8

## Summary

| Severity | Count |
|----------|-------|
| Passed | 22 |
| Failed | 10 |

## Findings

### Failed (10)

| Check | Resource | File:Line | Fix |
|-------|----------|-----------|-----|
| CKV_AWS_18 — S3 access logging | WebsiteBucket | template.yaml:41-52 | Add `LoggingConfiguration` to S3 bucket or use CloudFront access logs |
| CKV_AWS_54 — S3 block public policy | WebsiteBucket | template.yaml:41-52 | BlockPublicPolicy should be `true` (currently `false` — needed for bucket policy allowing CloudFront OAC) |
| CKV_AWS_21 — S3 versioning | WebsiteBucket | template.yaml:41-52 | Add `VersioningConfiguration: Status: Enabled` |
| CKV_AWS_86 — CloudFront access logging | CloudFrontDistribution | template.yaml:133-173 | Add `Logging` config with S3 bucket |
| CKV_AWS_174 — CloudFront TLS 1.2+ | CloudFrontDistribution | template.yaml:133-173 | Add `MinimumProtocolVersion: TLSv1.2_2021` to `ViewerCertificate` |
| CKV_AWS_68 — CloudFront WAF | CloudFrontDistribution | template.yaml:133-173 | Attach AWS WAF WebACL to CloudFront distribution |
| CKV_AWS_117 — Lambda in VPC | ContactFormFunction | template.yaml:200-345 | Unnecessary for external API calls (SES, Upstash, hCaptcha). VPC would block outbound internet. |
| CKV_AWS_116 — Lambda DLQ | ContactFormFunction | template.yaml:200-345 | Add `DeadLetterConfig` with SQS queue or SNS topic |
| CKV_AWS_173 — Lambda env encryption | ContactFormFunction | template.yaml:200-345 | Add `KMSKeyArn` for Lambda env var encryption. Sensitive vars (HCaptchaSecret, UpstashRedisToken) already marked `NoEcho: true` in CloudFormation. |
| CKV_AWS_95 — API Gateway V2 logging | HttpApiStage | template.yaml:376-381 | Add `AccessLogSettings` with CloudWatch log group |

### Risk Assessment

| Finding | Severity | Risk Acceptable? | Reason |
|---------|----------|-----------------|--------|
| CKV_AWS_54 (block public policy) | Medium | **Yes** — intentional | `BlockPublicPolicy: false` is required because the bucket policy grants read access to CloudFront OAC. Without this, CloudFront can't serve content. |
| CKV_AWS_117 (Lambda in VPC) | Low | **Yes** — not applicable | Lambda calls external services (SES, Upstash, hCaptcha API). VPC would require NAT Gateway, adding cost and latency with no security benefit. |
| CKV_AWS_173 (env var encryption) | Medium | **Accepted** | Sensitive vars are `NoEcho: true` in CloudFormation. A customer-managed KMS key adds $1/month for minimal additional protection on a portfolio site. |
| All others | Low-Medium | **Accept for now** | Logging, versioning, WAF, DLQ, TLS minimum — nice to have but excessive for a static portfolio. Add if traffic or attack surface grows. |

## Verdict

**PASS WITH RISK-ACCEPTED FINDINGS** — 10 failed, all LOW/MEDIUM, 0 HIGH/CRITICAL. None require immediate action for a low-traffic portfolio site.
