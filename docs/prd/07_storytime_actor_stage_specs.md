# 07 — StoryTime Actor Stage Specs

## Borrower story

### Stage: borrower logs in

Visible truths:

- borrower display name,
- preferred language,
- active loan count,
- latest loan status,
- unread lender messages.

Available decisions:

- ask about loan status,
- view loan details,
- view repayment schedule,
- read lender messages,
- ask what happens next,
- contact partner/support.

Blocked decisions:

- edit public loan story after loan is listed unless partner/staff route allows changes.
- reply directly to individual lender if demo only supports one-way encouragement.

Hidden decisions:

- staff risk review,
- lender portfolio data,
- partner internal notes.

### Stage: borrower views active loan

Askable questions:

- “How much has been funded?”
- “Who lent to me?”
- “When is my next payment?”
- “What happens if I am late?”
- “Can I apply again?”

Required surfaces:

- borrower dashboard,
- loan status card,
- repayment schedule card,
- translated encouragement messages,
- chat widget.

## Partner story

### Stage: partner starts new loan

Available decisions:

- create new borrower,
- select existing borrower,
- start another loan for existing borrower,
- upload photo URL,
- dictate borrower story,
- propose terms,
- submit for review.

Deferred decisions:

- submit loan requires borrower, amount, use, sector, activity, repayment terms, source locale, image, partner confirmation.

Generated cards:

- borrower match card,
- repeat-loan reuse suggestion card,
- missing facts checklist,
- loan application review form.

## Lender story

### Stage: lender discovers loans

Available decisions:

- ask for recommendations,
- filter by impact goal,
- compare loans,
- lend fake amount,
- save loan,
- join/create team,
- write encouragement.

Askable questions:

- “Find women-owned businesses in Guatemala.”
- “Show loans that are almost funded.”
- “What’s the risk here?”
- “What does pre-disbursed mean?”
- “Can I support climate resilience?”

### Stage: lender creates team

Available decisions:

- describe team audience,
- approve generated name/tagline/description,
- fetch/suggest image URL,
- invite demo members,
- publish team,
- request translations.

## Staff/admin story

### Stage: staff reviews loan submission

Visible truths:

- source-language content,
- translated rows and status,
- borrower/partner history,
- image/photo metadata,
- trust model,
- repayment terms,
- risk summary,
- AI-generated warnings,
- missing fields.

Available decisions:

- approve for translation,
- request changes,
- approve listing,
- reject listing,
- assign review,
- ask AI to summarize risk,
- inspect permission/audit events.

Hidden from staff unless elevated:

- full permission management,
- AI prompt secrets,
- system config.

## Cross-actor reveal: lender encouragement to borrower

```yaml
source_actor_stage: lender.loan_profile.viewed
source_decision: write_encouragement
truth_created: encouragement_message.draft
thresholds:
  - moderation_approved
  - translation_available_or_fallback_allowed
  - borrower_visibility_allowed
target_actor_stage: borrower.active_loan.message_view
surfaces:
  - borrower_portal_messages
  - borrower_android_messages_later
support_visibility:
  - message_moderation_status
  - translation_status
  - displayed_locale
```

## Cross-actor reveal: partner loan submission to staff

```yaml
source_actor_stage: partner.loan_application.review_ready
source_decision: submit_for_review
truth_created: loan_application.submitted
threshold: commitment
revealed_to:
  - staff.review_queue
  - translation_queue_if_source_needs_translation
  - admin.audit_timeline
target_available_decisions:
  - approve
  - request_changes
  - reject
  - assign_translation
```
