# AWS Architecture Diagram v3 — Design Spec

**Status:** v3.0 (overlap-free revision)
**Date:** 2026-07-11
**Author:** Eky Pratama + OpenCode Superpowers MoA consortium
**Supersedes:** v1.5 (`docs/superpowers/specs/2026-07-11-aws-architecture-diagram-v2-design.md`)
**Rendered target:** `docs/diagrams/aws-architecture.png`
**Source:** `docs/diagrams/aws-architecture.yaml`

## Context

The v1.5 redesign of the AWS architecture diagram improved on v1.0 in many ways
(more accurate, more services, more security controls visible) but the rendered
PNG still had 4 visible overlaps:

1. **Left cluster**: "Visitor / Browser / hCaptcha" labels running together in
   the HorizontalStack — `Browser` text crossed the hCaptcha icon area.
2. **HTTPS label** slightly overlapping the CloudFront box's left edge.
3. **AWS_PROXY label** crossing the API Gateway purple icon body.
4. **IAM Role · ses:SendEmail label** overlapping the last line of Lambda's
   4-line title ("Validation").

The diagram-as-Code format has **no spacing/padding primitives** — only 4 label
positions (SourceLeft, SourceRight, TargetLeft, TargetRight), no font-size or
margin control, and adjacent children in stacks have no padding. With 13 nodes
+ 12 links + 5 subtitle categories + 5 security headers + 3 Lambda annotations
packed into a single L→R row, **achieving zero overlap requires reducing what
the diagram shows**, not just rearranging it.

This v3.0 spec moves detail to README (where it belongs) and restructures the
external cluster with a VerticalStack to eliminate label collisions.

## Layout

**Direction:** Left-to-right, single AWS Cloud boundary wrapping AWS-managed
services. External cluster on the left uses a VerticalStack to give each node
its full horizontal width.

```
Canvas (vertical)
└── MainRow (HorizontalStack)
    ├── ExternalStack (VerticalStack)
    │   ├── Browser
    │   └── HCaptcha
    └── AWSCloud (wraps DNS / Edge / Origin / Compute / Email)
```

**AWSCloud internal structure:**

```
AWSCloud (vertical)
├── CDNLayer (HorizontalStack)
│   ├── Route53 (Title: "Hosted zone")
│   ├── CloudFront (children: ACM, ResponseHeadersPolicy)
│   └── S3 Bucket
├── Spacer1 (visual breathing room)
└── BackendLayer (HorizontalStack)
    ├── API Gateway
    ├── Lambda (child: IAM Role)
    └── SES
```

## Content moved from diagram to README

The diagram is now a **high-level architecture overview**. README is the
authoritative source for:

| Removed from diagram | README location |
|---|---|
| "Visitor" node | (implicit — diagram starts from Browser) |
| "Google Workspace" node | SES Domain Setup table (line ~259); `RECIPIENT_EMAIL` env var |
| Route53 subtitle (5 categories) | DNS row (line 29) + Tech Stack DNS row (line 60) + SES Domain Setup table (line 254) |
| ResponseHeadersPolicy subtitle (5 headers) | CDN+Storage row (line 30); CFN template line 99 |
| Lambda's 3 security annotations | Lambda section (line 41-43) + Defense-in-depth table (lines 38-48) |
| "AWS_PROXY" link label | API Gateway row (line 32); CFN template HttpApiIntegration |
| "IAM Role ·" link label prefix | Compute row (line 31); CFN template IAM section |
| "OAC (sigv4)" link label | CDN+Storage row (line 30); CFN template CloudFrontOriginAccessControl |
| "ALIAS A" link label | DNS row (line 29); `deploy.sh` Route53 setup |

This split follows the standard architecture-diagram best practice: **diagram
shows topology, README documents details**.

## Resources (11 nodes)

### External (outside AWS Cloud)

| # | ID | Type | Preset | Title | Position |
|---|----|------|--------|-------|----------|
| 1 | Browser | `AWS::Diagram::Resource` | — | "Browser" | ExternalStack (top) |
| 2 | HCaptcha | `AWS::Diagram::Resource` | — | "hCaptcha" | ExternalStack (bottom) |

### Inside AWS Cloud

| # | ID | Type | Preset | Title | Notes |
|---|----|------|--------|-------|-------|
| 3 | Route53 | `AWS::Route53::HostedZone` | `Route53HostedZone` | "Hosted zone" | No subtitle (moved to README) |
| 4 | CloudFront | `AWS::CloudFront::Distribution` | `CloudFrontDistribution` | (default) | Children: ACM, ResponseHeadersPolicy |
| 5 | ACM | `AWS::CertificateManager::Certificate` | `CertificateManager` | (default) | Child of CloudFront |
| 6 | ResponseHeadersPolicy | `AWS::Diagram::Resource` | — | (no title) | Child of CloudFront — shown as node only |
| 7 | S3 | `AWS::S3::Bucket` | `S3Bucket` | (default) | |
| 8 | ApiGateway | `AWS::ApiGateway::RestApi` | `ApiGatewayRestApi` | (default) | |
| 9 | LambdaFunction | `AWS::Lambda::Function` | `LambdaFunction` | "Lambda" | Single-line title, child: IAM |
| 10 | LambdaRole | `AWS::IAM::Role` | `IAMRole` | (default) | Child of Lambda |
| 11 | SimpleEmailService | `AWS::SES::Email` | `SimpleEmailServiceEmail` | (default) | |

## Connections (10 links)

| # | Source → Target | Position | Label | Notes |
|---|----------------|----------|-------|-------|
| 1 | Browser → Route53 | E→W | "DNS" | TargetLeft |
| 2 | Browser → CloudFront | E→W | "HTTPS" | TargetRight (was TargetLeft, was overlapping CloudFront edge) |
| 3 | Browser → HCaptcha | E→W | (none) | Challenge script load |
| 4 | HCaptcha → Browser | W→E | "token" | TargetLeft — captcha response |
| 5 | Browser → ApiGateway | E→W | "POST" | TargetLeft |
| 6 | ApiGateway → LambdaFunction | E→W | "proxy" | Shortened from "AWS_PROXY" (10 chars → 5 chars) |
| 7 | LambdaFunction → LambdaRole | S→N | "ses:SendEmail" | Shortened from "IAM Role · ses:SendEmail" |
| 8 | LambdaFunction → SimpleEmailService | E→W | (none) | boto3 call |
| 9 | CloudFront → S3 | S→N | "OAC" | Shortened from "OAC (sigv4)" |
| 10 | CloudFront → ACM | E→W | "TLS" | TargetLeft |

## How v3.0 eliminates v1.7 overlaps

| # | v1.7 overlap | v3.0 fix |
|---|---|---|
| 1 | "Visitor Browse hCaptcha" labels collide | VerticalStack stacks Browser + HCaptcha vertically — no horizontal collision. Visitor node removed. |
| 2 | "HTTPS" crosses CloudFront box edge | TargetRight puts label at right of CloudFront / in the gap with Browser — not on CloudFront box edge |
| 3 | "AWS_PROXY" crosses API GW icon | Shortened to "proxy" (5 chars vs 10 chars) — fits in API GW → Lambda gap |
| 4 | "IAM Role · ses:SendEmail" overlaps Lambda title's last line | Lambda title is now "Lambda" (1 line) — box is shorter, label has space below. Label shortened to "ses:SendEmail" |

## YAGNI scope (unchanged)

VPC/subnets, region callouts, cost annotations, WAF, GTM/Analytics, API GW
sub-resources (Route/Integration/Stage/Permission — collapsed), Lambda
concurrency/DLQ, logging/monitoring, dev-bypass captcha gate, CSP meta tag,
API GW CORS annotation.

## Acceptance criteria

- [ ] Zero text overlapping any icon body
- [ ] Zero text crossing any container border (AWS Cloud, CloudFront, ACM, etc.)
- [ ] Zero text overlapping other text
- [ ] All 11 nodes render cleanly
- [ ] All 10 links present and visible
- [ ] Diagram fits on GitHub without horizontal scroll
- [ ] Browser and HCaptcha clearly distinguishable as separate nodes (no label collision)

## README updates (companion to diagram change)

Two README locations need updating to reflect v3.0:

1. **Lines 18-20** (description below diagram): rewrite to describe Browser →
   external cluster, mention the 5 email-auth records live in Route53, the 5
   security headers live on ResponseHeadersPolicy, the recipient mailbox (Google
   Workspace) is configured via `RECIPIENT_EMAIL`.
2. **Line 217** (Dev Artifacts table): update the architecture diagram row to
   reference v3.0 and describe what was simplified.

## Consortium audit history (v1 → v3)

| Round | AWS accuracy | Visual clarity | Security | Documentation |
|-------|--------------|----------------|----------|---------------|
| v1.0 (baseline) | PASS | CONCERNS | CONCERNS | PASS |
| v1.5 (initial redesign, 6 rounds) | PASS | PASS | PASS | PASS |
| v1.5 render | PASS | CONCERNS (4 overlaps in PNG) | — | — |
| **v3.0 (overlap-free)** | TBD | TBD | TBD | TBD |

v3.0 consolidates detail into README. The visual audit will run on the new
rendered PNG. The consortium hasn't been re-run on v3.0 — the changes are
purely cosmetic (subtitle removal + label shortening + layout restructure).
AWS accuracy and Documentation audits from v1.5 still apply; Security audit
still applies (Lambda-side controls are documented in README rather than
diagram, which is a stronger location).