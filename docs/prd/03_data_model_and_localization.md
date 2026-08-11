# 03 — Data Model and Localization Architecture

## Database decision

Use Postgres as the primary database for v1. It gives transactional integrity, relational joins, indexes, materialized views, JSONB escape hatches, full-text search, trigram search, and optional vector search later.

Do not add MongoDB for v1. The system can create Postgres-backed localized read models instead of introducing a second truth store.

## Localization principle

Canonical tables hold identity, relationships, numeric values, workflow state, and nonlocalized truth.

Language-content tables hold actor-facing text by locale.

The pattern is:

```text
loans      -> loans_lc
borrowers  -> borrowers_lc
partners   -> partners_lc
teams      -> teams_lc
sectors    -> sectors_lc
activities -> activities_lc
tags       -> tags_lc
faqs       -> faqs_lc
pages      -> pages_lc
```

Use `_lc` consistently. The user called these `loanslc`, but use snake_case in Postgres: `loans_lc`. If the team wants literal table names, rename consistently, not randomly like a raccoon with a label maker.

## Supported locales table

```text
locales
- id
- code                // en, de, es, fr, nl
- english_name
- native_name
- enabled
- default_fallback_code
- text_direction      // ltr for current demo
- number_format
- currency_format
- date_format
```

## Generic LC columns

Every major `_lc` table should include:

```text
id
<entity>_id
locale_code
source_locale_code
is_source
translation_status        // draft | machine | needs_review | approved | stale | rejected
translated_by_ai_model
translated_from_lc_id
human_reviewer_user_id
reviewed_at
published_at
version
source_hash
field_completeness_score
created_at
updated_at
```

## Canonical content-source columns

For authoring in any language:

```text
source_locale_code        // selected by author
canonical_content_lc_id   // optional pointer to chosen source row
content_version
content_updated_at
```

The source language is not always English. If a partner authors a borrower story in Spanish, the Spanish row is source. English/German/French/Dutch rows are translations from Spanish.

## Translation status lifecycle

```text
draft
  -> source_submitted
  -> machine_translated
  -> needs_human_review
  -> approved
  -> published
  -> stale_when_source_changes
  -> retranslated
```

For demo v1, machine translation can be mocked. The important part is the state machine and review trail.

## Locale fallback

Default chain:

```text
requested locale -> base locale -> en
```

For current demo:

```text
de -> en
es -> en
fr -> en
nl -> en
```

Store fallback metadata when a localized read model uses fallback:

```text
fallback_used
fallback_locale_code
missing_fields
```

## Table groups

### Core identity

```text
users
user_profiles
roles
permissions
permission_groups
user_permission_groups
user_permissions
permission_audit_events
locale_preferences
```

### Borrower and partner

```text
borrowers
borrowers_lc
borrower_businesses
borrower_businesses_lc
borrower_groups
borrower_group_memberships
partners
partners_lc
partner_regions
trustees
trustees_lc
trust_endorsements
trust_endorsements_lc
alternative_checks
blockchain_attestations
```

### Loan lifecycle

```text
loans
loans_lc
loan_borrowers
loan_terms
loan_use_details
loan_use_details_lc
loan_status_events
loan_disbursals
repayment_schedules
repayment_schedule_items
repayment_events
loan_funding_allocations
loan_risk_summaries
loan_risk_summaries_lc
```

### Taxonomy/content

```text
sectors
sectors_lc
activities
activities_lc
themes
themes_lc
tags
tags_lc
countries
countries_lc
currencies
faq_entries
faq_entries_lc
wiki_pages
wiki_pages_lc
videos
videos_lc
```

### Lenders and teams

```text
lenders
lender_profiles
lender_profiles_lc
lending_teams
lending_teams_lc
lending_team_memberships
team_message_boards
team_posts
team_posts_lc
lender_impact_goals
saved_searches
```

### Messaging and translation

```text
message_threads
messages
messages_lc
message_moderation_events
translation_requests
translation_jobs
translation_reviews
encouragement_messages
encouragement_messages_lc
borrower_updates
borrower_updates_lc
```

### AI dialogue

```text
ai_agents
ai_conversations
ai_messages
ai_tool_calls
ai_action_previews
ai_command_confirmations
ai_graphql_queries
ai_page_context_snapshots
ai_prompt_versions
```

### Read models

Use materialized tables for hot reads:

```text
localized_loan_cards
localized_loan_profiles
localized_partner_cards
localized_team_cards
localized_borrower_portal_summaries
localized_homepage_sections
```

These are projections, not truth. Rebuild after canonical or LC changes.

## Example: loans and loans_lc

```text
loans
- id
- public_id
- status
- partner_id nullable
- trust_model                 // partner_facilitated | direct | trustee_backed | social_underwritten | blockchain_attested | hybrid
- country_code
- sector_id
- activity_id
- loan_amount_cents
- funded_amount_cents
- currency_code
- disbursal_status            // pre_disbursed | post_disbursed | direct_disbursal_pending | direct_disbursed
- disbursed_at nullable
- fundraising_started_at
- fundraising_ends_at
- repayment_term_months
- repayment_frequency
- source_locale_code
- canonical_content_lc_id
- created_by_user_id
- submitted_by_partner_id
- reviewed_by_user_id
- created_at
- updated_at
```

```text
loans_lc
- id
- loan_id
- locale_code
- is_source
- source_locale_code
- title
- borrower_story
- loan_use
- short_description
- repayment_summary
- risk_summary_public
- partner_note_public
- ai_generated_summary
- translation_status
- version
- source_hash
- translated_from_lc_id
- human_reviewer_user_id
- reviewed_at
- published_at
```

## Example: lending_teams and lending_teams_lc

```text
lending_teams
- id
- slug
- owner_user_id
- visibility                 // public | private | invite_only
- image_url
- image_source               // uploaded | ai_suggested | external_url | placeholder
- default_locale_code
- member_count
- total_lent_cents
- created_at
- updated_at
```

```text
lending_teams_lc
- id
- lending_team_id
- locale_code
- is_source
- name
- tagline
- description
- welcome_post_template
- translation_status
- version
```

## Localized read model rule

List pages should query read models. Authoring and review pages should query canonical + LC tables.

Example:

```text
public loan browse -> localized_loan_cards
loan detail -> localized_loan_profiles
partner edit -> loans + loans_lc
translation queue -> *_lc rows where translation_status != approved
```

## Numeric truth vs localized presentation

Do not translate numbers. Store numeric truth once and localize labels/formatting.

Wrong:

```text
loans_lc.loan_amount_text = "1.000 €"
```

Better:

```text
loans.loan_amount_cents = 100000
loans.currency_code = "USD"
UI formats amount by locale and currency policy.
```

If a read model stores formatted text for speed, it is a cache and must be invalidated.

## Search

Demo v1:

- Use `tsvector` per locale where practical.
- Use `pg_trgm` for fuzzy name search.
- Use localized read-model columns for search result cards.

Later:

- Add embeddings per locale or cross-lingual embeddings for semantic discovery.
- Store embedding metadata with source text hash and locale.

## Translation request on demand

For message board posts and other long-tail content, do not pretranslate everything. Create translation on request:

```text
user views post in de
  -> no team_posts_lc row for de
  -> show fallback en + “translating…” state
  -> create translation_request
  -> background job writes team_posts_lc(de)
  -> LiveView updates when ready
```

## Audit requirements

Every LC row must know:

- who authored source,
- what language it was authored in,
- what it was translated from,
- whether AI produced it,
- whether a human approved it,
- whether source changed afterward,
- which page/read model currently uses it.
