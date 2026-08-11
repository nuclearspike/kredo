# 00 — Product Vision PRD

## Working title

**Kiva Future Demo: multilingual, chat-first global lending connection platform**

## Product thesis

Kiva-like lending should feel less like browsing a catalog and more like entering a living network of people, trust, stories, capital, repayment, encouragement, and impact. The demo should show how a modern system could make that network multilingual by default and AI-assisted at every surface without turning AI into an unsafe wizard holding a flamethrower in a broom closet.

The product is not just loans. The product is the evolving relationship between:

- borrowers seeking useful capital,
- partners/trustees helping them become legible and trustworthy,
- lenders choosing where their money and encouragement should go,
- lending teams organizing community identity,
- staff managing risk, translation, review, moderation, and operational trust,
- AI agents helping each actor understand and act safely in their own language.

## Demo goal

Build a credible, functional demo that can be presented to Kiva as a reimagined upgrade path. The demo should not clone the existing site. It should preserve the same fundamental actors and mission while showing a better architecture:

1. Fully multilingual data model.
2. Chat-first application and discovery flows.
3. Borrower-facing loan access in native language.
4. Partner-facing chat-assisted loan creation.
5. Lender-facing AI discovery, team creation, and encouragement messages.
6. Staff/admin tools with separate GraphQL surfaces and strong permission boundaries.
7. Translation, moderation, and review workflows treated as first-class product reality.
8. Trust networks, trustees, endorsements, alternative underwriting, and optional blockchain attestations.
9. Rich analytics/distribution graphs for profiles, teams, partners, portfolio allocation, and funding flow.

## Demo users

Create exactly these real login accounts for the first demo seed:

| Role | Email | Password | Purpose |
|---|---|---|---|
| Borrower | `borrower@kiva.org` | `password` | Borrower portal, native-language loan visibility, lender messages. |
| Lender | `lender@kiva.org` | `password` | Browse, lend, create lending team, write translated encouragement. |
| Partner | `partner@kiva.org` | `password` | Chat-first loan application creation and borrower reuse. |
| Admin/staff | `admin@kiva.org` | `password` | Staff tools, review, translation, permissions, dashboards. |

All four accounts must support locale preference and globe-dropdown override. Passwords are intentionally unsafe because this is demo seed data. Do not use this seed pattern for production.

## Supported demo languages

- English: `en`
- German: `de`
- Spanish: `es`
- French: `fr`
- Dutch: `nl`

Every major content object must support language sidecar records. The UI chrome, footer, navigation, forms, validation copy, chatbot copy, generated cards, message moderation explanations, and admin dashboards must switch language.

## Product modes

### Public visitor mode

A visitor can browse loans, sectors, activities, tags, themes, partner profiles, lending teams, FAQs, wiki/video pages, and help content in the chosen language. The floating chat widget can explain Kiva-like lending, risk, repayment, direct loans, partner-facilitated loans, teams, messages, and how to start.

### Lender mode

A lender can search for loans by goal, impact area, geography, repayment schedule, borrower story, sector, trust model, partner, team, and language. The lender can tell the AI what they want to accomplish, and the AI can move them through pages, filters, comparison cards, lending team creation, and encouragement messages.

### Borrower mode

A borrower can see their loan details, repayment schedule, funding progress, messages of encouragement, partner/staff updates, and FAQs in their native language. Borrowers can use a browser in an internet cafe or an Android device. The borrower can ask: “How much is left?”, “When is my next repayment?”, “Who funded me?”, “What did lenders say?”, “Can I apply again?”

### Partner mode

A partner can create and manage borrowers, loans, stories, photos, terms, disbursal status, repayment schedules, sectors/activities/tags, and loan updates. The first-class flow is chat-assisted: the partner talks to the system, uploads images, confirms facts, and receives a review form at the end.

The partner can say: “Let’s do another loan for Rosa’s weaving business.” The system should find the existing borrower, infer reuse candidates such as sector, activity, business description, prior loan history, common photo, and repayment reliability, then ask only what is missing or changed.

### Staff/admin mode

Staff can review loans, manage translations, inspect permissions, analyze permission outliers, moderate messages, configure localized content, operate trust networks, approve partners/trustees, review risk signals, and inspect GraphQL access logs. Admin chat uses a separate schema and must be more powerful but not omnipotent.

## Core anchor outcomes

1. A lender can find and fund a meaningful loan using natural-language intent in any supported language.
2. A partner can create a high-quality multilingual loan application through chat, then review a structured form before submission.
3. A borrower can understand their loan, repayment schedule, lender messages, and next steps in their native language.
4. Lenders and borrowers can exchange encouragement across languages with AI moderation and translation.
5. Lending teams can be created conversationally, with draft content, image suggestions, and multilingual pages.
6. Staff can audit content, permissions, translations, risk, moderation, and trust signals without manually spelunking through tables like a mole with a badge.
7. The system can demonstrate partner-facilitated, direct, trustee-backed, social-underwritten, and blockchain-attested loan paths as configurable trust models.

## Non-goals for demo v1

- No real money movement.
- No real borrower PII.
- No production authentication hardening beyond demo-safe placeholders.
- No real blockchain integration, only attestation model and mock proof display.
- No real external image scraping unless the implementation explicitly adds a safe, mocked provider.
- No real credit/background checks.
- No production translation vendor integration required; use mocked machine translation and review states.
- No attempt to perfectly replicate current Kiva internals.

## Technology posture

Preferred stack:

- Elixir / Phoenix / LiveView
- Ecto
- Postgres
- Absinthe GraphQL
- Oban-style jobs
- Gettext + CLDR/ICU-style pluralization/formatting
- Postgres full-text and trigram search
- Optional pgvector-compatible embedding layer later
- External AI provider adapter behind a behaviour/port

Do not use MongoDB in v1. The localization sidecar pattern in Postgres is enough and keeps transactional truth together.

## Product design principle

The site should feel like a living multilingual lending network with AI assistance, not a table editor wearing a blazer.
