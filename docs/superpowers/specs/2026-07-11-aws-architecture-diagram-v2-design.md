# AWS Architecture Diagram v2 — Design Spec

**Status:** v1.5 (consortium-audited through 6 rounds)
**Date:** 2026-07-11
**Author:** Eky Pratama + OpenCode Superpowers MoA consortium
**Rendered target:** `docs/diagrams/aws-architecture.png`
**Source:** `docs/diagrams/aws-architecture.yaml`

## Context

The v1.0 diagram (`docs/diagrams/aws-architecture.png` + `.yaml`) had several visual
issues: ACM Certificate rendered detached from CloudFront, Route53 had no source arrow,
API Gateway / Lambda boxes overlapped, IAM Role awkwardly nested under Lambda, stray
line segments around the OAC link, and missing context (User/Browser, hCaptcha, Google
Workspace). It also did not depict Lambda-side application-layer security controls
(rate limiting, origin check, input validation) or the full ResponseHeadersPolicy
configuration.

This v2 redesign restructures the diagram end-to-end to be clean, professional, and
fidelity-accurate to the actual CloudFormation template and Lambda implementation.

## Layout

**Direction:** Left-to-right, single AWS Cloud boundary wrapping the AWS-managed
services. External services (Visitor, Browser, hCaptcha, Google Workspace) sit outside
the AWS Cloud box.

**Top-level structure (Canvas):**

```
Canvas (vertical)
└── MainRow (HorizontalStack)
    ├── Visitor
    ├── Browser
    ├── hCaptcha
    ├── AWSCloud (wraps DNS / Edge / Origin / Compute / Email)
    └── Google Workspace
```

**AWSCloud internal structure (vertical):**

```
AWSCloud
├── CDNLayer (HorizontalStack)
│   ├── Route53
│   ├── CloudFront (children: ACM, ResponseHeadersPolicy)
│   └── S3 Bucket
├── Spacer1 (visual breathing room for TargetTop labels)
└── BackendLayer (HorizontalStack)
    ├── API Gateway
    ├── Lambda (child: IAM Role)
    └── SES
```

## Resources (13 nodes)

### External (outside AWS Cloud)

| # | ID | Type | Title | Notes |
|---|----|------|-------|-------|
| 1 | Visitor | `AWS::Diagram::Resource` | "Visitor" | Generic icon, end user |
| 2 | Browser | `AWS::Diagram::Resource` | "Browser" | Generic icon, user's browser |
| 3 | HCaptcha | `AWS::Diagram::Resource` | "hCaptcha" | Generic icon (no native preset), external SaaS |
| 4 | GoogleWorkspace | `AWS::Diagram::Resource` | "Google Workspace" | Email recipient downstream of SES |

### Inside AWS Cloud

| # | ID | Type | Preset | Title / Subtitle | Notes |
|---|----|------|--------|------------------|-------|
| 5 | Route53 | `AWS::Route53::HostedZone` | `Route53HostedZone` | "Hosted zone\nSPF · DKIM · DMARC\nMAIL FROM · ALIAS A" | 2-line subtitle covering 5 record categories |
| 6 | CloudFrontDist | `AWS::CloudFront::Distribution` | `CloudFrontDistribution` | (preset default) | Children: ACM, ResponseHeadersPolicy |
| 7 | ACMCertificate | `AWS::CertificateManager::Certificate` | `CertificateManager` | (preset default) | TLS cert, child of CloudFront |
| 8 | ResponseHeadersPolicy | `AWS::Diagram::Resource` | — | "HSTS · XFO DENY · XCTO · RP · XSS" | 5 security headers, child of CloudFront |
| 9 | S3 | `AWS::S3::Bucket` | `S3Bucket` | (preset default) | Origin for CloudFront |
| 10 | ApiGateway | `AWS::ApiGateway::RestApi` | `ApiGatewayRestApi` | (preset default) | HTTP API, POST / |
| 11 | LambdaFunction | `AWS::Lambda::Function` | `LambdaFunction` | "Lambda\nRate limit 3/min/IP\nOrigin check\nValidation + sanitization" | 3 internal annotations |
| 12 | LambdaRole | `AWS::IAM::Role` | `IAMRole` | (preset default) | Child of Lambda, IAM least privilege |
| 13 | SimpleEmailService | `AWS::SES::Email` | `SimpleEmailServiceEmail` | (preset default) | Sends to Google Workspace |

## Connections (12 links)

All labels at `TargetTop` to avoid icon overlap and right-edge clipping.

| # | Source | → Target | Position | Label | Notes |
|---|--------|----------|----------|-------|-------|
| 1 | Visitor | → Browser | default | (none) | Implicit user action |
| 2 | Browser | → Route53 | E→W | "DNS" | DNS query |
| 3 | Browser | → CloudFrontDist | E→W | "HTTPS" | TLS-terminated |
| 4 | Browser | → HCaptcha | E→W | (none) | Script load |
| 5 | HCaptcha | → Browser | W→E | "token" | Captcha response |
| 6 | Browser | → ApiGateway | E→W | "POST" | Contact form submission |
| 7 | ApiGateway | → LambdaFunction | E→W | "AWS_PROXY" | Lambda proxy integration |
| 8 | LambdaFunction | → LambdaRole | S→N | "IAM Role · ses:SendEmail" | Lambda assumes execution role |
| 9 | LambdaFunction | → SimpleEmailService | E→W | (none) | boto3 ses.send_email call |
| 10 | CloudFrontDist | → S3 | S→N | "OAC (sigv4)" | Origin Access Control, signed |
| 11 | CloudFrontDist | → ACMCertificate | E→W | "TLS" | ACM provides TLS cert |
| 12 | SimpleEmailService | → GoogleWorkspace | E→W | "email" | Email delivery to recipient inbox |

## YAGNI (Out of Scope)

- VPC / subnets (none used in this architecture)
- Region callouts for ap-southeast-2 / us-east-1 (minimal label choice)
- Cost annotations
- WAF (not deployed)
- GTM / Analytics (client-side, not architectural)
- API Gateway sub-resources (Route / Integration / Stage / Permission — collapsed into the single API Gateway icon)
- Lambda concurrency / DLQ
- Logging / monitoring resources
- Dev-bypass captcha gate (production-only diagram)
- CSP meta tag (browser-side, not architectural hop)
- API Gateway CORS `*` annotation (Lambda enforces origin at code level)

## Pre-existing README staleness (NOT fixed in this redesign)

Doc agent flagged that README line 27-29 (DNS row) is missing MAIL FROM and
README line 30 (CDN row) is missing XSS Protection. Diagram v1.5 is more accurate
than the prose. A separate docs-only PR is recommended to sync README.

## Acceptance Criteria

- [ ] 13 nodes render without overlapping boxes
- [ ] 12 links connect cleanly, no stray segments
- [ ] ACM + ResponseHeadersPolicy both render inside CloudFront box
- [ ] Route53 subtitle shows 5 categories (2 lines)
- [ ] Lambda shows 3 internal annotations (rate limit, origin check, validation)
- [ ] External services visually outside AWS Cloud boundary
- [ ] All critical labels at TargetTop (no icon overlap, no right-edge clipping)
- [ ] Diagram readable on GitHub desktop

## Consortium Audit Trail

| Round | AWS accuracy | Visual clarity | Security | Documentation |
|-------|--------------|----------------|----------|---------------|
| v1.0 (baseline) | PASS | CONCERNS | CONCERNS | PASS |
| v1.0 → v1.1 (initial redesign) | PASS | CONCERNS | CONCERNS | CONCERNS |
| v1.1 (consortium review) | PASS | CONCERNS | CONCERNS | CONCERNS |
| v1.1 → v1.2 (5 fixes) | PASS | CONCERNS | PASS | CONCERNS |
| v1.2 (consortium review) | PASS | CONCERNS | PASS | CONCERNS |
| v1.2 → v1.3 (Route53 widen + IAM label) | PASS | CONCERNS | PASS | PASS |
| v1.3 (consortium review) | PASS | CONCERNS | PASS | PASS |
| v1.3 → v1.4 (2-line subtitle + TLS TargetTop) | PASS | CONCERNS | CONCERNS | PASS |
| v1.4 (consortium review) | PASS | PASS | CONCERNS* | PASS |
| v1.4 → v1.5 (broaden TargetTop to all labels) | PASS | PASS | CONCERNS* | PASS |
| v1.5 (final consensus) | PASS | PASS | CONCERNS* | PASS |

\* Security agent's "CONCERNS" in v1.4 and v1.5 were entirely about YAML file
state (plan-mode blocker), not design issues. Design loop closed at v1.5.