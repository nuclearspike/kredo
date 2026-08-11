# 01 — Coding Agent Handoff: LSSD Operating Guide

## Prime directive

Build this demo using Living Systems Software Development: outcome-first, subsystem-first, truth-aware, reveal-driven, dialogue-first, command-safe, observable, and rewriteable.

Do not start by generating screens. Start by building subsystem reality and then project UI/chat affordances from actor stages.

## Agent read order

1. `README.md`
2. `00_product_vision_prd.md`
3. `02_system_tree_and_subsystems.md`
4. `03_data_model_and_localization.md`
5. `04_ai_chat_first_architecture.md`
6. `schemas/command_registry.yaml`
7. `schemas/database_model.yaml`
8. `schemas/graphql_surface_map.yaml`
9. `fractalflow/*.lssd.md`
10. `17_acceptance_tests_and_story_specs.md`

## Implementation posture

You are not building a normal CRUD app. You are building a demo of a future operating model. The code should be functional, but documentation fidelity matters because future agents will expand it.

For every implementation slice, update or create the nearest relevant planning doc and FractalFlow `.lssd.md` file. If a command, flow, policy, truth, localizable entity, reveal surface, notification, or GraphQL field changes, the docs must change in the same pass.

## Branch-scoped work rule

Do not attempt to implement the entire product at once. Pick one bounded branch:

- localization core,
- account/session/role seed,
- loan browse and localized loan cards,
- partner chat loan application,
- borrower portal,
- lender chat discovery,
- lending team creation,
- message moderation and translation,
- admin translation/review queue,
- permission outlier dashboard,
- trust network prototype.

Each branch must produce:

1. Working subsystem slice.
2. Tests.
3. Seed data.
4. FractalFlow update.
5. StoryTime actor-stage update or audit note.
6. Acceptance note in changelog.

## Evidence labels

When writing docs or model claims, use:

- `observed`: verified in code or seed data.
- `asserted`: stated by product docs or user intent.
- `inferred`: derived from adjacent structure.
- `unknown`: unresolved.
- `conflict`: two sources disagree.
- `confirmed`: human-reviewed.
- `deprecated`: retained for traceability.

For this bundle, almost everything is `asserted` until implemented.

## Build order

### Phase 0 — Skeleton and seeds

Create Phoenix project, Postgres, core accounts, sessions, roles, locale selection, fake seed data, and base layout with globe dropdown and floating chat placeholder.

### Phase 1 — Localization infrastructure

Implement canonical content + `*_lc` sidecar tables, fallback resolution, source locale tracking, translation jobs, translation status, per-field source tracking, and localized page chrome.

### Phase 2 — Loan browse and public content

Implement localized loan cards, loan profile pages, sectors, activities, tags, themes, partners, FAQs, footer, and wiki/video placeholders.

### Phase 3 — Chat-first substrate

Implement page-aware chat session context, Ask Mode, Command Mode stub, command registry, role-scoped GraphQL surfaces, and safe action previews.

### Phase 4 — Partner loan application chat

Implement partner flow: select/create borrower, capture story/photo/terms/use/sector/activity, reuse prior borrower facts, generate structured review form, submit for staff review.

### Phase 5 — Lender discovery and teams

Implement lender chat discovery, filtered loan cards, comparison cards, lending team creation, draft team page generation, message board, requested translations.

### Phase 6 — Borrower portal and messages

Implement borrower-native language dashboard, loan status, funding status, repayment schedule, lender messages, translated encouragement, AI explanations.

### Phase 7 — Admin/staff ops

Implement staff review queue, translation ops, moderation queue, permission outlier dashboard, partner/trustee review, audit timeline.

### Phase 8 — Trust network demo

Implement trustees, endorsements, social underwriting, alternative checks, mock blockchain attestations, and transparent risk/trust display.

## Hard boundaries

- AI can draft and propose. It does not mutate directly.
- All mutations go through command registry handlers.
- All actor questions are answered through scoped GraphQL query surfaces.
- Admin GraphQL schema is separate from public/lender/borrower/partner schemas.
- Do not expose admin-only fields through public schema and “filter later.” That is how ghosts get admin badges.
- Do not store localized content only in JSON blobs if it needs indexing, workflow, or review state.
- Do not translate numeric truth. Translate labels, summaries, and formatting.
- Do not let machine translation become approved content without review state.

## Definition of done for any branch

- The branch has at least one happy-path demo.
- There are tests for permission boundaries.
- Locales `en`, `de`, `es`, `fr`, `nl` show plausible content or fallback state.
- The chat assistant can explain the page state and suggest legal next actions.
- If a command is available through UI, the chat can invoke the same command path or explain why not.
- If a command is dangerous, there is a preview and confirmation.
- Admin can inspect what happened.
- Docs and FractalFlow are updated.
