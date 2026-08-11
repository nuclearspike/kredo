# 17 — Acceptance Tests and Story Specs

## Test philosophy

Tests should verify stories, not just controllers. Every actor stage should prove visible truths, available actions, hidden truths, command eligibility, localization, and audit.

## Global tests

### Locale switch

Given a public visitor is on loan browse
When they select German from globe dropdown
Then page chrome, footer, loan cards, sectors, activities, and chat greeting render in German or marked fallback.

### Fallback

Given a team post has no Dutch translation
When a Dutch user views it
Then fallback text appears with translation pending state
And a translation request is queued.

### Source language

Given partner authors a loan in Spanish
When translations are generated
Then Spanish `loans_lc` row is `is_source=true`
And English/German/French/Dutch rows reference it.

## AI Ask Mode tests

Given lender is viewing Rosa’s loan in German
When lender asks “Why is this loan pre-disbursed?”
Then assistant answers in German
And queries only Public/Lender GraphQL
And does not expose partner internal notes.

Given borrower asks about their repayment schedule
Then assistant queries BorrowerGraphQL
And returns only borrower-owned loan data.

## Command Mode tests

Given lender asks to create a team
When all required details are collected
Then assistant shows preview card
And does not create team until explicit confirmation.

Given partner asks to submit a draft loan
When required truths are missing
Then assistant asks for missing truths instead of submitting.

Given admin asks to change a permission group
Then assistant shows high-risk preview and requires confirmation.

## Partner loan application tests

- Existing borrower is matched.
- Reuse suggestions are shown with confidence/reason.
- Partner confirms reused sector/activity.
- Review form contains all required sections.
- Submission creates review queue item.
- Source locale is preserved.
- Translation jobs are created.

## Lender message tests

- Safe message passes moderation.
- Patronizing message triggers suggested rewrite.
- Unsafe message is blocked.
- Borrower sees approved translated message.
- Message moderation status is visible to staff.

## Permission tests

- Borrower cannot query lender private data.
- Lender cannot query borrower private portal data.
- Partner cannot query loans for other partners.
- Staff cannot manage permissions unless admin group.
- AI denied GraphQL calls are logged.

## Admin tests

- Translation queue filters by locale/status.
- Permission outlier dashboard shows direct unusual permissions.
- Admin can inspect AI tool call logs.
- Review queue shows source and translated rows.

## Trust/risk tests

- Partner-facilitated loan shows partner risk explanation.
- Direct loan shows direct-loan due diligence explanation.
- Trustee-backed loan shows endorsement.
- Blockchain attestation is displayed as mock attestation, not repayment proof.

## StoryTime audit tests

Run periodic audit checks:

- every available decision maps to command/question/collection/control/silence,
- every hidden decision has a policy,
- every consequential command has preview/confirmation,
- every LC row has source and status,
- every public localized read model has fallback metadata,
- every lender encouragement message has moderation status,
- every borrower-visible translation has source trace.
