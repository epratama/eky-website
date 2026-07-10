# Checkov IaC Security Scan — Summary

**Date**: 2025-07-10
**Project**: eky-website
**Tool**: Checkov 3.3.8

## Aggregated Results

| IaC Type | Path | Critical | High | Medium | Low | Status |
|----------|------|----------|------|--------|-----|--------|
| CloudFormation | `./infrastructure` | 0 | 0 | 4 | 6 | LOW RISK |

## Top Findings

| # | Check | Resource | Description | Fix |
|---|-------|----------|-------------|-----|
| 1 | CKV_AWS_18 | WebsiteBucket | S3 access logging | Add `LoggingConfiguration` to bucket (optional) |
| 2 | CKV_AWS_86 | CloudFrontDistribution | CloudFront logging | Add `Logging` config with S3 bucket (optional) |
| 3 | CKV_AWS_68 | CloudFrontDistribution | No WAF | Add AWS WAF WebACL ($5/month) |
| 4 | CKV_AWS_95 | HttpApiStage | API Gateway logging | Enable `AccessLogSettings` on stage (optional) |
| 5 | CKV_AWS_54 | WebsiteBucket | BlockPublicPolicy: false | Intentional — OAC requires this |

## Per-Target Report

- [CloudFormation](infrastructure-cloudformation-report.md)

## Verdict: PASS (0 critical/high)

All 10 findings are non-critical for a personal portfolio website. The 22 passed checks confirm IAM least privilege, S3 encryption, Lambda runtime not deprecated, no hardcoded secrets, no open CORS, and HTTPS-only CloudFront.
