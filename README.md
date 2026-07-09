# Portfolio Website

Single-page neo-brutalist portfolio website. Fully automated deployment — one
command builds, tests, provisions infrastructure, uploads, and configures DNS.
55 tests across 4 suites. 14 AWS resources managed via CloudFormation.
Developed entirely with **OpenCode** (AI coding agent) using **Superpowers** skills.

---

## Architecture

```
                 Route53 ──────────────────────────────┐
                 (yourdomain.com, www)                 │
                    │ ALIAS A                          │
                    ▼                                  │
     ┌──────────────────────────────┐   ACM cert       │
     │  CloudFront (HTTPS, HTTP/3)  │◄──us-east-1──────┘
     └──────────┬───────────────────┘
                │ OAC
                ▼
     ┌──────────────────┐
     │  S3 (static site) │
     └──────────────────┘

     ┌──────────┐     ┌───────────────┐     ┌──────────┐     ┌─────┐
     │  hCaptcha │────▶│  API Gateway  │────▶│  Lambda  │────▶│ SES │
     │  invisible│     │  HTTP API     │     │  Python  │     │     │
     └──────────┘     └───────────────┘     │  3.12    │     └──┬──┘
                                            │          │        │
                                            │ Origin ✓ │  SPF + DKIM
                                            │ Rate 3/m │  + DMARC
                                            │ CORS     │        │
                                            └──────────┘        ▼
                                                            📧 inbox
```

### Defense-in-depth

| Layer | Mechanism |
|---|---|
| **Bot protection** | hCaptcha (invisible, server-side verification) |
| **Origin restriction** | Lambda rejects requests from unknown domains (403) |
| **Rate limiting** | 3 requests/minute/IP — sliding window (429) |
| **CORS** | Restricted to domain (not `*`) |
| **Concurrency** | Lambda reserved concurrency: 5 |
| **SPF** | `v=spf1 include:_spf.google.com include:amazonses.com ~all` |
| **DKIM** | 3 signing keys via Amazon SES |
| **DMARC** | `p=none` — monitoring mode (reports to admin email) |

---

## Methodology

Built with **OpenCode** (AI coding agent) using the **Superpowers** skill system.

### Production Engineering

Moving beyond simple scripting to automated multi-step deployment with
mock-testable components and infrastructure-as-code:

- **CloudFormation** provisions 14 AWS resources in a single `deploy` command
- **`deploy.sh`** handles SES domain setup, certificate auto-detection,
  Route53 DNS, frontend build, S3 upload, and CloudFront invalidation
- **Idempotent operations** — skips already-configured resources (SES domain,
  Route53 records, cert)
- **30 shell unit tests** using mocked AWS CLI verify every code path

### Architectural Governance

Designed secure connections between AWS services:

- Route53 → CloudFront: ALIAS A records with ACM certificate (us-east-1)
- CloudFront → S3: Origin Access Control (OAC) with bucket policy
- API Gateway → Lambda: AWS_PROXY integration, payload format 2.0
- Lambda → SES: custom domain sender with full SPF/DKIM/DMARC alignment
- SES domain verification, MAIL FROM MX, DKIM CNAMEs — all automated in deploy script

### Product Feedback Loop

Identified technical friction points and built automated guardrails into `deploy.sh`:

| Friction | Resolution |
|---|---|
| `AWS::Lambda::Url` blocked by org policy | Switched to API Gateway HTTP API |
| DMARC rejection when sending from external domain via SES | Custom SES domain sender with SPF/DKIM alignment |
| SES sandbox: emails silently fail if sender not verified | Automated `verify-email-identity` + polling loop in deploy script |
| JMESPath bracket notation fails on `@` character | Switched to escaped dot notation |
| CloudFront managed policy IDs differ by region | Replaced with inline `AWS::CloudFront::CachePolicy` resources |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | React 18, Vite 6, Tailwind CSS 3, Lucide React |
| **Backend** | Python 3.12, AWS Lambda, API Gateway HTTP API |
| **Email** | AWS SES (SPF + DKIM + DMARC) |
| **Hosting** | S3 + CloudFront (HTTPS, HTTP/3, HTTP/2, compression) |
| **DNS** | Route53 (ALIAS A, SPF TXT, DKIM CNAMEs, DMARC TXT, SES verification TXT, MAIL FROM MX) |
| **IaC** | CloudFormation (14 resources, 6 parameters) |
| **Testing** | Vitest + testing-library (12), pytest (13), bash mocks (30) |
| **Design** | Neo-brutalism (ui-ux-pro-max design system) |
| **CI/CD** | `deploy.sh` — 1 command: build → test → deploy → invalidate |

---

## Superpowers Skills Used

| OpenCode Feature | Superpowers Skill | How Used |
|---|---|---|
| **Plan mode** | `brainstorming` | Design spec → clarifying Q&A → design approval |
| **Plan mode** | `writing-plans` | 20-task implementation roadmap with file paths + code |
| **Subagent dispatch** | `subagent-driven-development` | 20 tasks executed in parallel with per-task code reviews |
| **Skill invocation** | `ui-ux-pro-max` | Neo-brutalist design system (styles, palettes, fonts, spacing) |
| **Skill invocation** | `ponytail` | Over-engineering audits: cut dead code, removed unused dependencies |
| **Skill invocation** | `test-driven-development` | RED-GREEN-REFACTOR cycle: tests written before implementation |

---

## Test Suites

| Suite | Language | Tests | Command |
|---|---|---|---|
| **Frontend components** | JSX (Vitest) | 12 | `cd frontend && npm test` |
| **Lambda backend** | Python (pytest) | 13 | `cd backend && .venv/bin/pytest` |
| **Deploy script** | Bash (mocks) | 13 | `./test-deploy.sh` |
| **CF template** | Bash (validation) | 17 | `./test-template.sh` |
| **Total** | | **55** | |

### What the tests cover

| Area | Tests verify |
|---|---|
| **App smoke** | Renders without crash, all 7 section IDs, title, social links |
| **Contact form** | Field rendering, empty validation, email format, filled form clears errors |
| **Scroll reveal** | Returns `{ref, isVisible}`, `prefers-reduced-motion` → immediate |
| **Experience** | Descending chronological order (current role before internship) |
| **Lambda validation** | Name/email/message required, email format, JSON decode error |
| **Lambda security** | Origin rejection, rate limit (3/min then 429), CORS restriction, HTML escaping |
| **Deploy flow** | Stack check, SES verify/decline/auto-verify, cert detect (issued/pending/none), cert request, Route53 DNS (skip/update/non-Route53) |
| **CF template** | Syntax validation, 14 resources present, 6 parameters, secrets marked `NoEcho` |

---

## Deploy

Single command deploys everything:

```bash
./deploy.sh <stack-name>
```

### Full Pipeline

| Phase | What happens |
|---|---|
| **Pre-flight** | Checks `aws`, `jq`, `npm` installed. Queries CloudFormation for existing stack config. |
| **Interactive prompts** | Sender/recipient emails (prefilled from stack if exists), hCaptcha secret (hidden input). |
| **SES email verification** | Checks if sender + recipient are verified in SES. If not: sends verification email, polls every 5s (up to 2.5 min) until confirmed. Declining aborts deploy. |
| **ACM certificate** | Auto-searches for existing ISSUED cert in us-east-1. If found: reuses. If PENDING: shows DNS records and exits. If none: offers to request new, shows validation CNAMEs. |
| **CloudFormation deploy** | Builds parameter overrides, runs `cloudformation deploy`. After deploy: verifies DomainName + CertificateArn were applied, warns if not. |
| **Build + upload** | Runs `vite build` with API Gateway URL + hCaptcha site key. Syncs `dist/` to S3 with `--delete`. Creates CloudFront invalidation. |
| **Route53 DNS** | If custom domain configured: finds hosted zone, auto-creates ALIAS A records (root + www) pointing to CloudFront. Skips if already correct. |

All operations are idempotent — running twice produces the same result.

### SES Domain Setup

When the sender email uses a custom domain (not gmail.com etc.) and the domain
is on Route53, `deploy.sh` automatically configures email authentication:

| Step | Record | Purpose |
|---|---|---|
| **Domain verification** | `_amazonses.domain.com` TXT | Proves you own the domain to SES |
| **SPF (sender auth)** | `domain.com` TXT (`v=spf1 include:amazonses.com`) | Receiving servers know SES is allowed. Merges with existing Google Workspace SPF if present. Preserves non-SPF TXT records. |
| **DKIM (signing)** | `*._domainkey.domain.com` CNAME × 3 | Cryptographically signs every email — prevents tampering and improves trust score |
| **MAIL FROM (envelope)** | `mail.domain.com` MX + SPF TXT | Custom bounce/return-path domain so SPF aligns with the `From` header |
| **DMARC (policy)** | `_dmarc.domain.com` TXT (`p=none`) | Tells receivers: "if SPF or DKIM fail, still deliver but send me reports." Monitors abuse before upgrading to `p=reject`. |

Without these: emails land in spam (or are rejected). With all five: full
SPF + DKIM + DMARC alignment → inbox delivery.

All operations are idempotent — running `deploy.sh` again skips anything
already configured.

---

## Design

Neo-brutalism — hard borders, chunky shadows, flat colors, bold type.

| Token | Value |
|---|---|
| Background | `#FAFAFA` |
| Text | `#09090B` |
| Primary | `#18181B` |
| Accent | `#2563EB` |
| Border | `3px solid #18181B` |
| Shadow | `4px 4px 0 #18181B` |
| Fonts | Archivo (headings) + Space Grotesk (body) + JetBrains Mono (mono) |
| Favicon | Inline SVG "EP" monogram |

---

## License

MIT
