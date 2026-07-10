# Resume Website — Design Spec

**Date**: 2025-07-09
**Last updated**: 2025-07-09 (v2 — post-launch)
**Project**: Eky Pratama Resume Website
**Goal**: Personal portfolio landing page showcasing 15+ years of software engineering experience

## Overview

Single-page React SPA with AWS serverless contact form backend. Neo-brutalist visual style — bold, distinctive, animated, with hard borders, chunky shadows, and flat colors. Hosted on S3 + CloudFront via CloudFormation, deployed with automated shell scripts.

## Architecture

```
User → Route53 (ekyputrapratama.com, www) → CloudFront (HTTPS, ACM cert) → S3 (static React build)
                                                 ↓
User → hCaptcha → API Gateway HTTP API → Lambda (Python 3.12) → SES → Eky's email
                                                    ↓
                                    Origin check (ALLOWED_ORIGIN)
                                    Rate limit (3 req/min/IP)
                                    CORS restricted to domain
```

- **Frontend**: React 18+ via Vite, no routing, anchor-scroll navigation, 14 Vitest tests. CSP meta tag restricts scripts, fonts, and connections to allowed origins.
- **Backend**: Python 3.12 Lambda behind API Gateway HTTP API (Lambda::Url blocked by org policy). Validates + hCaptcha verify + SES send. Origin validation (urlparse exact match), rate limiting (requestContext.sourceIp), restricted CORS, input length limits, CR/LF stripping. 26 pytest tests.
- **Infrastructure**: CloudFormation — S3 bucket, CloudFront distribution with OAC + inline policy resources, API Gateway HTTP API (5 resources), Lambda function, IAM roles, SES configuration
- **DNS**: Route53 hosted zone with ALIAS A records for root + www, SES domain verification, SPF, DKIM (3 keys), DMARC (p=none), MAIL FROM domain
- **Resume data**: Static JSON file in frontend (single source of truth, easy to update)
- **Testing**: 70 tests total across 4 suites (14 frontend + 26 Lambda + 13 deploy + 17 CF template)

## Visual Design System

### Style: Neo-Brutalism

| Token | Value |
|---|---|
| Background | `#FAFAFA` (zinc-50) |
| Text | `#09090B` (zinc-950) |
| Primary | `#18181B` (zinc-900) |
| Muted | `#3F3F46` (zinc-700) |
| Accent | `#2563EB` (blue-600) |
| Border | `3px solid #18181B` |
| Shadow | `4px 4px 0 #18181B` |
| Shadow hover | `8px 8px 0 #18181B` |
| Border radius | `0px` (default) |
| Gradients | None |
| Blur/opacity overlays | None |
| Favicon | Inline SVG "EP" monogram — slate background, accent blue text |

### Typography

| Role | Font | Weights |
|---|---|---|
| Headings | Archivo | 600, 700, 800 |
| Body | Space Grotesk | 400, 500, 600 |
| Monospace accents | JetBrains Mono | 400, 500 |

### Icons & Visuals

- **Lucide React** for all functional icons (24x24, consistent stroke-width)
- **Inline SVG** decorative geometric shapes (squiggles, stars, blobs) in accent blue (#2563EB) as background ornament
- **No images**, no emojis, no stock photos
- Borders and shadows carry visual weight

### Animations

| Trigger | Effect | Duration |
|---|---|---|
| Section enter viewport | translateY(40px)→0 + opacity 0→1 | 400ms ease-out |
| Card hover | shadow expands 4px→8px, border color holds | 200ms |
| Staggered reveals | Each card in grid delayed +80ms per index | — |
| Form validation | Instant red border + error text snap (no transition) | 0ms |
| Submit button | bg↔fg color inversion on hover | 150ms |

- `prefers-reduced-motion`: all animations disabled, elements appear instantly
- No infinite animations, no decorative motion

## Page Sections

### 1. Home (id="home")
- Asymmetric layout: text block offset left with accent geometric SVG on right
- Name in Archivo 800, large (clamp 3rem→6rem)
- Title: "Technical Lead & Senior Software Engineer"
- Location: North Sydney, NSW, Australia
- LinkedIn + GitHub buttons side-by-side in flex row, identical brutalist style
- Mobile: `min-h-[90vh] pt-20 pb-12`, desktop: `min-h-screen pt-24 pb-16`
- Favicon: inline SVG "EP" monogram

### 2. Summary
- Bordered card with offset shadow
- 3-4 line condensed paragraph from resume summary
- Accent bar on left edge

### 3. Key Achievements
- 7 cards in responsive grid (1col mobile, 2col tablet, 3col desktop)
- Each: number (#1-7) in large bold accent, title, description
- Card: 3px border, 4px shadow, bg white
- Scroll-triggered staggered reveal

### 4. Experience
- Vertical timeline: left border "track" with timeline nodes centered on border
- Descending chronological order (most recent first)
  - Swift Digital: October 2013 – Present (Technical Lead & Senior Software Engineer)
  - Internetrix: November 2011 – January 2012 (Software Engineer Internship)
- Each card: company/dates, role title, bullet points (collapsed, expand on click)
- Timeline nodes as accent-filled circles straddling the border track

### 5. Skills
- Grouped by category in bordered blocks:
  - Agentic AI Architecture
  - Cloud Infrastructure
  - Business Process
  - Database Engineering
  - Security & Compliance
  - Operations & Methodology
  - Languages & Frameworks
- Each skill as a bordered "tag" with hover shadow

### 6. Education + Certifications
- Two-column layout
- Left: degrees (University of Wollongong, 2011, 2013)
- Right: certifications with IDs/links

### 7. Contact
- "Get in touch" heading
- Form fields (all bordered inputs, no radius):
  - Name (required) — text
  - Email (required) — email
  - Mobile (optional) — tel
  - Message (required) — textarea
- hCaptcha invisible — triggers on valid form submit
- Validation: instant red border + bold error text (no animation)
- Submit: black button, inverts on hover, shows `Loader2` spinner + "Sending..." on loading
- Success: form replaced by bold confirmation message
- Error: error state shown inline, user can retry; generic message only (no internal `err.message` leaked)

### 8. Build Showcase
- Section number "07" — positioned after contact form, before footer
- Bordered card with accent left bar, scroll-reveal animation
- "Want to know how this site was built?" headline
- GitHub link button to source code repository (epratama/eky-website)

### 9. Footer
- Dark background (`#18181B`) with white text
- Name, role title, LinkedIn + GitHub icon links (matched pair)
- "Top" button scrolls to `#home`

## Responsive Breakpoints

| Breakpoint | Layout |
|---|---|
| 375px (mobile) | Single column, stacked, reduced Hero padding (`pt-20 pb-12`), `min-h-[90vh]` |
| 768px (tablet) | 2-column grids where applicable |
| 1024px (desktop) | Full layout with offsets, 3-column achievement grid |
| 1440px+ | Max-width container 1152px (max-w-6xl), centered |

## Backend (Lambda Python 3.12)

### API Endpoint
`POST /` — API Gateway HTTP API (not Lambda Function URL — blocked by org policy)

### Request
```json
{
  "name": "string (required)",
  "email": "string (required, validated)",
  "mobile": "string (optional)",
  "message": "string (required)",
  "hcaptcha_token": "string (required)"
}
```

### Security Layers

| Layer | Implementation |
|---|---|
| **Origin check** | `ALLOWED_ORIGIN` env var — `urlparse` exact scheme+netloc match, rejects subdomain bypass (403 Forbidden). Removes `www.` prefix for comparison. |
| **Rate limiting** | 3 requests per minute per IP, sliding window. Uses `requestContext.sourceIp` (not spoofable `x-forwarded-for` header). |
| **CORS** | `Access-Control-Allow-Origin` restricted to `ALLOWED_ORIGIN` (not `*`) |
| **hCaptcha** | Server-side token verification via hcaptcha.com. `ALLOW_CAPTCHA_BYPASS` env var gates dev-bypass (default: `"false"` in production). |
| **Input validation** | Name/email/message required, email format regex. Length limits: name ≤200, email ≤254, mobile ≤50, message ≤10000. CR/LF stripped from name and mobile. |
| **HTML escaping** | `_esc()` sanitizes `& < > " '` (5 chars) before email rendering |
| **Error sanitization** | Client receives generic "Something went wrong" — internal errors logged via `console.error`, not exposed |
| **Concurrency** | Lambda reserved concurrency: 5 |

### Email

- **From**: `Eky Pratama Portfolio <me@ekyputrapratama.com>` (display name + custom domain)
- **Subject**: `Portfolio contact from {name} via ekyputrapratama.com`
- **Body**: HTML + text/plain, includes contact details + source footer
- **Authentication**: SPF (`include:amazonses.com + _spf.google.com`), DKIM (3 keys), DMARC (`p=none`)

### Flow
1. Rate limit check (sliding window, 3/min/IP from `requestContext.sourceIp`)
2. Origin check against `ALLOWED_ORIGIN` using `urlparse` exact matching
3. Parse and validate JSON body
4. Validate required fields + email format + length limits
5. Strip CR/LF from name and mobile
6. Verify hCaptcha token via `https://hcaptcha.com/siteverify` (unless `ALLOW_CAPTCHA_BYPASS=true` and token is `dev-bypass`)
6. On success: send email via SES to configured recipient
7. Return `{ success: true }` or `{ error: "message" }`

### Errors
- 400: validation failure, length limit exceeded, or hCaptcha rejection
- 403: origin check failure
- 429: rate limit exceeded
- 500: SES send failure

## CloudFormation Resources

| Resource | Type | Purpose |
|---|---|---|
| WebsiteBucket | `AWS::S3::Bucket` | Static website hosting |
| WebsiteBucketPolicy | `AWS::S3::BucketPolicy` | CloudFront OAC access |
| CloudFrontDistribution | `AWS::CloudFront::Distribution` | HTTPS, HTTP/3, custom domain (+www aliases) |
| CloudFrontOriginAccessControl | `AWS::CloudFront::OriginAccessControl` | OAC for S3 |
| CloudFrontCachePolicy | `AWS::CloudFront::CachePolicy` | Optimized caching |
| CloudFrontOriginRequestPolicy | `AWS::CloudFront::OriginRequestPolicy` | Origin request headers |
| CloudFrontResponseHeadersPolicy | `AWS::CloudFront::ResponseHeadersPolicy` | Security headers |
| LambdaExecutionRole | `AWS::IAM::Role` | Lambda permissions |
| ContactFormFunction | `AWS::Lambda::Function` | Python 3.12, inline ZipFile code |
| HttpApi | `AWS::ApiGatewayV2::Api` | HTTP API (replaces blocked Lambda::Url) |
| HttpApiIntegration | `AWS::ApiGatewayV2::Integration` | Lambda proxy integration |
| HttpApiRoute | `AWS::ApiGatewayV2::Route` | POST / |
| HttpApiStage | `AWS::ApiGatewayV2::Stage` | $default, auto-deploy |
| LambdaApiPermission | `AWS::Lambda::Permission` | API Gateway invoke permission |

## Automation Scripts

### deploy.sh
Single command deploys everything: `./deploy.sh eky-website`

1. Dependency check (aws, jq, npm)
2. Stack existence check + current config display
3. Interactive prompts (emails, hCaptcha, domain, cert)
4. SES email verification check (send verification + poll if needed)
5. **SES domain setup** (SPF, DKIM, DMARC, MAIL FROM) via Route53 — idempotent
6. ACM certificate auto-detection (find issued cert, reuse)
7. CloudFormation stack deploy
8. Post-deploy validation (verify DomainName + CertificateArn applied)
9. Frontend build with correct env vars
10. S3 upload + CloudFront cache invalidation
11. Route53 ALIAS record auto-configuration (skip if already correct)

### deploy.sh (13 shell tests)
Mock-based smoke tests covering: stack not found, full deploy, missing deps, cert auto-detect (issued/pending/not found), cert request, domain-without-cert blocking, Route53 (skip upsert / update / non-Route53), SES verification (verified / decline / verify).

### test-template.sh (17 tests)
Validates CloudFormation template: syntax check, key resources present, all 6 parameters present, HCaptchaSecret marked NoEcho.

### backend/test_lambda.py (13 pytest tests)
Origin validation, rate limiting, CORS, input validation, JSON parsing, HTML escaping.

## What's Not Included

- No PDF download/rendering
- No photo/avatar
- No blog or multi-page routing
- No CMS or admin panel
- No analytics (add later if needed)
