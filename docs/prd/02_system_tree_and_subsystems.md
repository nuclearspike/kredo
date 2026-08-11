# 02 — System Tree and Subsystems

## Product trunk

**Kiva Future Demo** is a multilingual, chat-first lending network that models borrower, partner, lender, staff, and trustee stories around loans, trust, funding, repayment, translation, and connection.

## Major subsystems

### 1. Identity and access subsystem

Owns users, roles, sessions, locale preference, permission groups, actor profiles, and access policies.

Anchor outcomes:

- Four demo accounts can log in.
- Each user has an actor type and permission set.
- Staff can inspect permission outliers.
- GraphQL schema exposure is role-scoped.

### 2. Localization and language content subsystem

Owns supported locales, globe dropdown, UI chrome translation, `*_lc` sidecar tables, translation workflows, fallback, source locale, machine translation, human review, and requested translations.

Anchor outcomes:

- Every major content page can switch `en/de/es/fr/nl`.
- Users can author in one language and generate translations for others.
- Translation rows track source status, reviewer status, and fallback.

### 3. Loan lifecycle subsystem

Owns loan application, borrower association, group loans, terms, use of funds, sector/activity/tag/theme, disbursal state, fundraising, funding allocation, repayment schedule, repayment events, default/risk state, and completion/outcome.

Anchor outcomes:

- Partner can create a loan through chat.
- Lender can fund a fake loan.
- Borrower can see their loan status and repayment schedule.
- Staff can review loan content and state transitions.

### 4. Borrower and group subsystem

Owns borrowers as independent actors/entities who may appear in multiple loans, group memberships, businesses, profiles, borrower photos, story reuse, prior repayment history, and native-language borrower portal.

Anchor outcomes:

- Borrower can appear in a group loan and later a solo or different group loan.
- Partner can reuse borrower data for repeat loans.
- Borrower profile and loan story are distinct.

### 5. Partner/trustee/trust network subsystem

Owns lending partners, trustees, trust endorsements, due diligence, alternative background checks, partner risk, partner regions, social underwriting, and mock blockchain attestations.

Anchor outcomes:

- A loan can be partner-facilitated, direct, trustee-backed, social-underwritten, blockchain-attested, or hybrid.
- Lenders can see a transparent trust/risk explanation.

### 6. Lender experience subsystem

Owns lender profile, portfolio, loan search, recommendations, lending basket, fake checkout, lending history, impact goals, saved searches, and AI discovery.

Anchor outcomes:

- Lender can ask for loans matching intent.
- Lender can understand risk and repayment.
- Lender can send moderated encouragement.

### 7. Lending team subsystem

Owns team creation, team profile, team language content, team image, message board, member roles, team lending stats, team distribution graphs, and requested message translations.

Anchor outcomes:

- Lender can create a team conversationally.
- AI can draft localized team page content.
- Team message board posts translate on request.

### 8. Messaging, moderation, and translation subsystem

Owns lender encouragement messages, borrower updates, partner/staff notes, translation requests, AI moderation, message visibility, and cross-language display.

Anchor outcomes:

- Lenders can write encouragement.
- AI rejects/rewrites cruel or unsafe messages.
- Borrowers can read approved messages in native language.

### 9. AI dialogue subsystem

Owns page-aware chat, bot personas by actor, system prompts, schema-scoped GraphQL tools, command previews, guided collection, generated cards, and audit logs.

Anchor outcomes:

- Every page has a floating chat widget.
- Chat can answer questions in the selected language.
- Chat can control page navigation and propose actions safely.

### 10. Admin/staff operations subsystem

Owns review queues, translation queues, moderation queues, permissions dashboard, loan status control, partner/trustee management, risk review, and system audit timeline.

Anchor outcomes:

- Staff can see what the system knows and why.
- Staff can inspect outlier permissions.
- Staff can approve/reject translations and content.

### 11. Analytics and distribution graph subsystem

Owns profile distribution graphs, portfolio allocation, team/lender/partner distributions, language coverage, translation debt, funding velocity, repayment status, permission outliers, and AI usage metrics.

Anchor outcomes:

- Demo includes graphs showing global distribution and engagement.
- Staff can explain where loans, lenders, teams, and partners are concentrated.

## Cross-subsystem dependencies

Localization is required by every actor-facing subsystem.

AI dialogue depends on:

- identity/access,
- page context,
- role-scoped GraphQL,
- command registry,
- localization,
- audit logging.

Loan lifecycle depends on:

- borrowers,
- partners/trust networks,
- localization,
- review/translation,
- fake finance,
- messaging,
- analytics.

Messaging depends on:

- moderation,
- translation,
- borrower/lender visibility,
- loan relationship proof,
- audit.

Admin depends on all subsystems but must access them through explicit admin/staff surfaces, not magic queries under the floorboards.
