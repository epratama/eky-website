# Resume Website — Design Spec

**Date**: 2025-07-09
**Project**: Eky Pratama Resume Website
**Goal**: Personal portfolio landing page showcasing 15+ years of software engineering experience

## Overview

Single-page React SPA with AWS serverless contact form backend. Neo-brutalist visual style — bold, distinctive, animated, with hard borders, chunky shadows, and flat colors. Hosted on S3 + CloudFront via CloudFormation.

## Architecture

```
User → CloudFront (HTTPS) → S3 (static React build)
                                 ↓
User → hCaptcha → Lambda Function URL (Python) → SES → Eky's email
```

- **Frontend**: React 18+ via Vite, no routing, anchor-scroll navigation
- **Backend**: Python 3.12 Lambda, invoked via Function URL, validates + hCaptcha verify + SES send
- **Infrastructure**: CloudFormation — S3 bucket, CloudFront distribution, Lambda function, IAM roles, SES configuration
- **Resume data**: Static JSON file in frontend (single source of truth, easy to update)
- **Testing**: Vitest + @testing-library/react + jsdom. 10 tests across 3 suites (App smoke, ContactForm validation, useScrollReveal hook). Run with `npm test`.

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
| Border radius | `0px` (default), `4px` on select elements |
| Gradients | None |
| Blur/opacity overlays | None |

### Typography

| Role | Font | Weights |
|---|---|---|
| Headings | Archivo | 700, 800 |
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

### 1. Hero
- Asymmetric layout: text block offset left with accent geometric SVG on right
- Name in Archivo 800, large (clamp 3rem→6rem)
- Title: "Technical Lead & Senior Software Engineer"
- Location: North Sydney, NSW
- LinkedIn link with Lucide icon
- Scroll-down indicator (animated arrow SVG)

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
- Vertical timeline: left border "track" with role cards branching off
- Each card: company/dates, role title, bullet points (collapsed, expand on click)
- Current role (Swift Digital) prominently at top
- Timeline nodes as accent-filled circles on the track

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
- Submit: black button, inverts on hover, shows loading state
- Success: form replaced by bold confirmation message
- Error: error state shown inline, user can retry

## Responsive Breakpoints

| Breakpoint | Layout |
|---|---|
| 375px (mobile) | Single column, stacked sections, smaller type |
| 768px (tablet) | 2-column grids where applicable |
| 1024px (desktop) | Full layout with offsets, 3-column achievement grid |
| 1440px+ | Max-width container 1280px, centered |

## Backend (Lambda Python)

### API Endpoint
`POST /` — Lambda Function URL

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

### Flow
1. Validate input (present, format, length)
2. Verify hCaptcha token via `https://hcaptcha.com/siteverify`
3. On success: send email via SES to configured recipient
4. Return `{ success: true }` or `{ error: "message" }`

### Errors
- 400: validation failure
- 429: rate limit (Lambda reserved concurrency)
- 500: SES/hCaptcha failure

## CloudFormation Resources

| Resource | Type |
|---|---|
| S3Bucket | `AWS::S3::Bucket` — website hosting, public read via CloudFront OAI |
| CloudFrontDistribution | `AWS::CloudFront::Distribution` — HTTPS, S3 origin, custom domain support |
| LambdaFunction | `AWS::Lambda::Function` — Python 3.12, Function URL enabled |
| LambdaInvokePermission | `AWS::Lambda::Permission` — Function URL public access |
| SESConfiguration | `AWS::SES::ConfigurationSet` + verified identity |
| IAMRole | Lambda execution: SES send + CloudWatch Logs |

## What's Not Included

- No PDF download/rendering
- No photo/avatar
- No blog or multi-page routing
- No CMS or admin panel
- No analytics (add later if needed)
