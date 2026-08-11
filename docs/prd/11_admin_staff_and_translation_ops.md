# 11 — Admin, Staff, Review, Translation, and Moderation Operations

## Admin principle

Admin should not be a junk drawer of tables. Admin is an operational truth surface. It shows what requires attention, why, what can be done, and what will happen if staff confirms.

## Staff dashboard cards

- Loan applications needing review.
- Translations needing review.
- Messages needing moderation.
- Permission outliers.
- Partner/trustee due diligence queue.
- Missing localizations by language.
- AI tool-call denials.
- Funding velocity anomalies.
- Repayment schedule exceptions.

## Translation ops

### Queue filters

- entity type,
- locale,
- source locale,
- translation status,
- AI generated,
- stale after source update,
- reviewer assigned,
- public page impact,
- priority.

### Actions

- approve translation,
- reject translation,
- edit translation,
- request retranslation,
- mark source row as canonical,
- compare source and target,
- publish.

## Moderation ops

Moderation queue includes:

- lender encouragement messages,
- team message board posts,
- borrower updates,
- partner story drafts.

Actions:

- approve,
- reject,
- suggest rewrite,
- mark needs human review,
- hide public display,
- escalate.

## Loan review ops

Review queue includes:

- borrower identity summary,
- partner identity,
- loan amount/use/terms,
- source story,
- translations,
- photo,
- trust model,
- risk/trust summary,
- repayment schedule,
- missing fields,
- AI reviewer notes.

Actions:

- request partner changes,
- approve translation step,
- approve listing,
- reject listing,
- assign reviewer,
- add note.

## Permission outlier dashboard

Required graphs/cards:

- direct user permissions by role,
- users with rare permission combinations,
- partners with cross-partner access,
- translator/reviewer mismatches by language,
- admin permissions unused recently,
- AI denied tool calls by schema surface,
- staff with borrower/lender account overlap.

## Admin chat

Admin chat can ask:

- “Which loans are blocked by missing German translation?”
- “Show permission outliers.”
- “Why was this message rejected?”
- “Which partners have the slowest repayment reporting?”
- “Summarize Rosa’s repeat-loan application.”

Admin chat must use StaffGraphQL/AdminGraphQL and command registry previews. It cannot directly update rows.

## Audit timeline

Every consequential action creates audit:

- actor,
- role,
- page,
- command,
- preview shown,
- confirmation,
- object ids,
- changed truths,
- notifications sent,
- translation/moderation status,
- AI tool calls used.
