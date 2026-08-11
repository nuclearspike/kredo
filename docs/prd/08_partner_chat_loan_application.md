# 08 — Partner Chat-First Loan Application

## Anchor outcome

A partner can create a complete, localized, reviewable loan application by chatting naturally with the system, reusing known borrower facts when appropriate, and reviewing a structured form before submission.

## Happy path: repeat borrower

Partner says:

> Let’s go ahead and do another loan for Rosa’s weaving business.

System:

1. Resolves partner identity.
2. Searches partner-owned borrowers for Rosa.
3. Shows borrower match card.
4. Pulls prior loans.
5. Suggests reuse candidates:
   - business name,
   - sector,
   - activity,
   - region,
   - prior story summary,
   - prior loan use pattern,
   - repayment reliability.
6. Asks what changed:
   - amount,
   - exact use of funds,
   - repayment term,
   - new photo/update,
   - group membership changes.
7. Drafts source-language content.
8. Generates translations for `de/es/fr/nl/en` as needed.
9. Shows structured review form.
10. Partner confirms.
11. Loan enters staff review queue.

## Guided collection sequence

```yaml
flow: partner_repeat_loan_application
turns:
  - resolve_existing_borrower
  - confirm_business_context
  - confirm_loan_amount
  - capture_loan_use
  - confirm_sector_activity_tags
  - capture_terms
  - capture_disbursal_status
  - capture_photo_or_reuse_existing
  - generate_story_draft
  - generate_translations
  - present_review_form
  - partner_confirm_submission
```

## Required truths

```yaml
required_truths:
  borrower_id:
    source: partner_selection_or_match
    authority: partner
  loan_amount:
    source: partner_declaration
    validation: positive_money
  loan_use:
    source: partner_declaration
    localizable: true
  sector_id:
    source: reuse_or_partner_confirmation
  activity_id:
    source: reuse_or_partner_confirmation
  repayment_term:
    source: partner_declaration
  repayment_schedule:
    source: system_generated_with_partner_confirmation
  source_locale:
    source: partner_selection
  borrower_story:
    source: partner_chat_draft_confirmed
    localizable: true
  photo_url:
    source: partner_upload_or_reuse
```

## Reuse confidence

Reuse suggestions must be shown with confidence and reason:

```yaml
reuse_suggestion:
  field: activity_id
  value: weaving
  confidence: 0.92
  reason: "Rosa's last two loans used the weaving activity and same business profile."
  requires_partner_confirmation: true
```

Never silently reuse story content as if current. Ask what changed.

## Review form sections

1. Borrower identity and group membership.
2. Business profile.
3. Loan amount and use.
4. Sector/activity/tags/themes.
5. Disbursal status.
6. Repayment schedule.
7. Public story and short summary.
8. Photo/image.
9. Translations and missing locale status.
10. Risk/trust model.
11. Partner confirmation.

## Commands

- `partner.start_loan_application`
- `partner.select_existing_borrower`
- `partner.create_borrower`
- `partner.apply_reuse_suggestion`
- `partner.generate_loan_story_draft`
- `partner.request_translations`
- `partner.submit_loan_for_review`
- `partner.save_loan_draft`

## Staff review handoff

After submission:

- Staff gets review queue item.
- Translation queue receives source row and generated target rows.
- Admin audit receives event.
- Partner sees submitted state and can ask status.

## Demo script

Use account: `partner@kiva.org` / `password`

Suggested demo phrase:

> Let's do another loan for Rosa Alvarez's weaving business. She needs $950 to buy cotton thread and natural dyes, same sector and activity as before, 8 month term, monthly repayments. Use Spanish as the source language.

Expected result:

- borrower match card for Rosa,
- reused sector/activity,
- generated Spanish source story,
- translations pending/available for English, German, French, Dutch,
- review form,
- submit button.
