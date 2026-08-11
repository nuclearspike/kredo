# 15 — Roadmap and Coding Agent Work Packages

## Phase 0 — Project shell

Work packages:

1. Phoenix/LiveView shell.
2. Postgres/Ecto baseline.
3. Demo accounts and sessions.
4. Base layout with globe dropdown.
5. Floating chat widget placeholder.
6. Seed data loader.

Acceptance:

- Four demo accounts can log in.
- Locale switch changes UI chrome/footer.
- Fake seed data loads.

## Phase 1 — Localization core

Work packages:

1. Locales and locale preference.
2. Translation status enum/state machine.
3. Generic LC pattern helpers.
4. Sidecar tables for loans, borrowers, partners, teams, sectors, activities, tags, FAQs.
5. Fallback resolver.
6. Localized read models for loan cards.

Acceptance:

- Loan list changes language.
- Missing locale uses fallback and records fallback state.
- Authoring source language can be non-English.

## Phase 2 — Public/lender browse

Work packages:

1. Loan card browse.
2. Loan profile.
3. Sector/activity/tag filters.
4. Partner profile cards.
5. Lending team public profile.
6. Lender basket/fake lend.

Acceptance:

- Lender can browse and fake fund a loan.
- Loan profile explains pre-disbursal and risk.

## Phase 3 — AI substrate

Work packages:

1. AI conversation tables.
2. Page context provider.
3. Role-scoped GraphQL query logger.
4. Ask Mode stub.
5. Command registry loader.
6. Action preview cards.
7. Command confirmation flow.

Acceptance:

- Chat can answer page-specific loan questions from GraphQL.
- Chat can propose but not directly execute commands.

## Phase 4 — Partner application flow

Work packages:

1. Partner borrower search.
2. Existing borrower reuse suggestions.
3. Chat-guided loan draft.
4. Photo URL capture.
5. Review form.
6. Submit for review.
7. Translation job mock.

Acceptance:

- Partner can create repeat loan for Rosa through chat.

## Phase 5 — Lender teams and messages

Work packages:

1. Lender team create/edit.
2. AI team draft generation.
3. Team image suggestion mock.
4. Team message board.
5. On-demand post translation.
6. Encouragement message moderation.
7. Borrower-visible translated messages.

Acceptance:

- Lender creates team conversationally.
- Lender sends approved translated encouragement.

## Phase 6 — Borrower portal

Work packages:

1. Borrower dashboard.
2. Loan status card.
3. Repayment schedule card.
4. Lender messages view.
5. Borrower chat Ask Mode.
6. Contact partner/support path.

Acceptance:

- Borrower sees loan and messages in Spanish.
- Borrower asks repayment question and gets localized answer.

## Phase 7 — Staff/admin ops

Work packages:

1. Staff review queue.
2. Translation queue.
3. Moderation queue.
4. Permission outlier dashboard.
5. Admin GraphQL schema.
6. Audit timeline.
7. AI tool-call inspector.

Acceptance:

- Admin can see review/translation/moderation queues and permission outliers.

## Phase 8 — Trust network demo

Work packages:

1. Trustee profiles.
2. Trust endorsements.
3. Alternative checks.
4. Mock blockchain attestations.
5. Risk/trust explanation card.
6. Trust analytics.

Acceptance:

- Loan profile can show partner-facilitated/direct/trustee/social/blockchain trust cards.

## Work package template

```yaml
work_package:
  id:
  branch:
  anchor_outcome:
  files_to_create_or_modify:
  docs_to_update:
  commands:
  graphql_fields:
  policies:
  ui_surfaces:
  tests:
  seed_data:
  acceptance:
  forbidden_shortcuts:
```
