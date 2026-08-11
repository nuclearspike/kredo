# Implementation Log

Running changelog for the Kiva Future Demo build. Evidence labels follow
`01_agent_handoff_lssd.md`: `observed` = verified in code/tests, `asserted` =
from product docs, `inferred` = derived.

Stack: Elixir 1.19 / Phoenix 1.8 / LiveView / Ecto / Postgres 17 / Absinthe.
DB connects to the local Postgres `/tmp` socket as `$USER` (see `config/dev.exs`).

**Status: all phases 0–8 complete.** `mix test` → 104 tests, 0 failures;
`mix compile --warnings-as-errors` clean; `mix ecto.reset` rebuilds the full
schema + seeds from scratch. See per-phase `Verified` blocks below.

Acceptance cross-check (`17_acceptance_tests_and_story_specs.md`): locale
switch + fallback + source-language preservation ✓; AI Ask Mode via scoped
GraphQL + Command Mode preview/confirm ✓; partner reuse + review-queue +
translation jobs ✓; lender message moderation (pass/rewrite/block) + borrower
translated view ✓; role-scoped GraphQL allow/deny + denied-call logging ✓;
admin review/translation/outlier/AI-log/audit ✓; trust-model + endorsement +
mock attestation ✓. Single audited command path + LC source/status + fallback
metadata are structural invariants of the model.

---

## Phase 0 — Skeleton & seeds  `observed`

**Delivered**

- Phoenix app generated at repo root (app `:kiva`, module `Kiva`); planning docs
  preserved (`README_PLANNING.md`, `docs/`, `schemas/`, `prompts/`).
- Migration `create_core`: `locales`, `users`, `roles`, `permissions`,
  `permission_groups`, `permission_group_permissions`, `user_permission_groups`,
  `user_permissions`. `users.default_locale_code` FK → `locales.code`.
- Contexts: `Kiva.Accounts` (bcrypt auth, role field, timing-safe login),
  `Kiva.Localization` (supported set `en/de/es/fr/nl`, `fallback_chain`,
  locale-aware `format_money`).
- Auth: `KivaWeb.UserAuth` session login/logout + plugs
  (`fetch_current_user`, `require_authenticated_user`, `require_role`) + LiveView
  `on_mount` hooks (`:mount_current_user`, `:ensure_authenticated`,
  `{:ensure_role, roles}`). `SessionController`, `LocaleController`.
- Locale: `KivaWeb.Plugs.SetLocale` (params > session > user default > base),
  globe-dropdown language switcher in the app shell.
- Layout: `Layouts.app` shell with localized header/footer, globe dropdown, and a
  **floating page-aware chat placeholder** (`Layouts.chat_widget`) on every page.
- Route stubs (filled in later phases): `/loans`, `/portal` (borrower),
  `/partner` (partner), `/admin` (staff/admin), each role-guarded via
  `live_session` + `on_mount`.
- Seeds (idempotent): 5 locales, 5 roles, 11 permissions, 5 permission groups,
  4 demo accounts (`borrower|lender|partner|admin@kredo.test` / `password`).

**Verified**

- `mix test` — 30 tests, 0 failures (Accounts, Localization, page render, session
  login/logout, **role permission boundaries** on `/portal` and `/admin`).
- HTTP smoke: localized home, `/login` 200, `/loans` LiveView w/ chat widget,
  `/admin` anon → 302 `/`, `/locale/es` → 302 back.

**Notes / simplifications**

- `users.role` (string) is an `inferred` extension of `database_model.yaml` to
  carry the actor type used for schema-surface scoping.
- Gettext message catalogs for `de/es/fr/nl` are populated in Phase 1; Phase 0
  proves the switching mechanism (session + `Gettext.put_locale`).

---

## Phase 1 — Localization infrastructure  `observed`

**Delivered**

- Migration `create_localization_content`: `faq_entries`, `faq_entries_lc` (full
  generic `*_lc` column set per `03_data_model`), `translation_requests`.
- `Kiva.Localization.Resolver` — pure fallback resolver over `*_lc` rows
  (`requested -> en`), reports `fallback_used` / `missing`. This is the reusable
  primitive every later localized entity uses.
- `Kiva.Translation` — **mock** machine translator (deterministic, glossary-tagged
  `[to←from]`), `source_hash/1` for staleness, translation-request upserts.
  Lifecycle: draft → machine → needs_review → approved → published → stale.
- `Kiva.Content` — localized FAQ fetch with per-entry fallback metadata,
  on-demand `ensure_faq_translation/3` (idempotent), `approve_faq_translation/2`.
  Machine output is displayed but badged unreviewed; never auto-approved.
- `KivaWeb.FaqLive` (`/faq`) — localized FAQ with honest fallback badges
  (`showing EN`, `machine · review pending`, `human`) and a one-click
  "Translate to <locale>" affordance demonstrating the long-tail flow.
- **Gettext catalogs** authored for `de/es/fr/nl` (42 chrome strings each) — the
  globe dropdown now visibly localizes nav, home, login, footer, chat widget.
- Seeds: 3 FAQ entries (en source; `es`/`fr` translations present; `de`/`nl`
  intentionally missing to demo fallback + on-demand machine translation).

**Verified**

- `mix test` — 45 tests, 0 failures (resolver fallback, mock translator,
  content/translation lifecycle, FAQ LiveView translate-on-demand, **chrome i18n
  switching** asserting Spanish/German rendered text).
- HTTP smoke: `/` + `/faq` render Spanish/German chrome via cookie session;
  untranslated FAQ falls back to EN with badge; translate button present.

**Notes**

- The `localization_subsystem` translation_lifecycle behavior is realized in code
  here (FAQ exemplar); the `.lssd.md` model itself was only brought to `observed`
  later, in the dedicated FractalFlow sync pass (see end of log). Materialized
  read models (`localized_*`) are
  deferred — list pages query canonical+LC directly until volume warrants caching.
- No Oban: translation "jobs" run synchronously in the mock translator; the
  `translation_requests` trail is real.

---

## Phase 2 — Loan browse & public content  `observed`

**Delivered**

- Migration `create_loans`: `sectors(_lc)`, `activities(_lc)`, `partners(_lc)`,
  `borrowers(_lc)`, `loans(_lc)`, `repayment_schedules`,
  `repayment_schedule_items`. All sidecars use the lean shared `*_lc` column set.
- Schemas (12) + contexts: `Kiva.Taxonomy`, `Kiva.Partners`, `Kiva.Lending` —
  all returning localized reads (canonical numeric truth + resolved `*_lc` text +
  fallback flags). `Lending.funded_percent/1`, repayment schedule generation.
- `Resolver.resolve_public/2` + `display_rows/1` extracted as the shared
  display-eligibility filter (reused by FAQ + loans).
- Pages: `/loans` (localized cards + sector/country/trust-model/text filters —
  the `localizedLoanSearch` surface), `/loans/:slug` (full profile w/ story, use,
  risk, repayment schedule — `localizedLoanProfile`), `/partners/:slug`.
  Reusable `<.loan_card>` / `<.funding_bar>` components.
- Seeds: 3 sectors + 3 activities (localized), 3 partners, 3 borrowers, 3 loans
  with en+es content (de/fr/nl fall back), repayment schedules. Borrower Rosa
  linked to the `borrower@kredo.test` account.

**Verified**

- `mix test` — 53 tests, 0 failures (Lending localization + fallback + filters +
  schedule, LoanLive browse/profile, es content vs de fallback badge).
- HTTP smoke: `/loans` lists seeded loans; `/loans/rosa-weaving-second-loan`
  shows Spanish story under `es`; `/partners/...` renders.
- The loan_lifecycle browse/profile reads are realized in code here; the
  `loan_lifecycle_subsystem.lssd.md` model was updated to match in the
  FractalFlow sync pass (see end of log), not in this phase.

**Notes**

- GraphQL exposure of these reads is Phase 3 (per build order); contexts are the
  seam Absinthe resolvers will call.
- ~22 new Phase-2 UI labels (loan-page chrome) currently fall back to English
  when switching locale (catalogs scaffolded, not yet translated); loan *content*
  is fully localized. Country names use a static English map (simplification).

---

## Phase 3 — Chat-first substrate  `observed`

**Delivered**

- Migration `create_ai_and_audit`: `audit_events`, `ai_conversations`,
  `ai_messages`, `ai_tool_calls`, `ai_action_previews`.
- `Kiva.Commands` — **the single mutation path**. Registry mirrors
  `command_registry.yaml` (8 commands); `preview/3` + `execute/4` re-run every
  gate (role → required inputs → eligibility → handler → audit). `set_locale`
  has a real handler; others preview but return `{:not_implemented}` until their
  phase. `Kiva.Commands.Eligibility` holds named checks. `Kiva.Audit` trail.
- `Kiva.AI` persistence context + `Kiva.AI.Assistant` — a deterministic mock LLM
  (offline, key-free) with the real provider boundary: **Ask Mode** answers by
  running role-scoped GraphQL via `Absinthe.run`; **Command Mode** previews a
  registered command and proposes an explicit confirm. Every turn/tool-call/
  preview is recorded.
- **Role-scoped GraphQL** (`KivaWeb.Schema`): public `localizedLoans`,
  `localizedLoan`, `localizedPartner`, `faqEntries`, `viewer`; `staffReviewQueueCount`
  (staff/admin) and `auditEvents` (admin) gated by an `Authorize` middleware
  against the actor role in context. Mounted at `/api/graphql` (+ GraphiQL in dev).
- `KivaWeb.ChatComponent` — the floating chat is now **live** on every LiveView
  page (Ask answers + Command confirm buttons; set_locale confirm redirects
  through `/locale/:code`). Controller pages keep the static placeholder.

**Verified**

- `mix test` — 67 tests, 0 failures (command registry gating + audit + execute,
  GraphQL scoping allow/deny, assistant Ask/Command modes + tool-call recording,
  live chat open→ask and command→confirm→redirect).
- HTTP smoke: `POST /api/graphql` returns localized loans; `staffReviewQueueCount`
  denied to public; `#kiva-chat` present on `/loans`.
- The ai_dialogue command-mode flow is realized in code here; the
  `ai_dialogue_subsystem.lssd.md` model was updated to `observed` in the
  FractalFlow sync pass (see end of log), not in this phase.

**Notes**

- Assistant replies are English (mock); the chat *chrome* is gettext-localized.
  The provider seam (`Kiva.AI.Assistant`) is where a real Claude adapter drops in.
- `set_locale` skips a confirm step per spec, but the UI still routes it through
  preview→confirm to exercise Command Mode.

---

## Phase 4 — Partner loan application chat  `observed`

**Delivered**

- Migration `add_partner_link`: `users.managed_partner_id` → `partners`.
- `Kiva.LoanApplications` — draft loans (status `draft`), borrower **reuse
  suggestions** (sector/activity/country/business + prior loan terms),
  `update_draft` (canonical + source `loans_lc`), `draft_complete?`, and
  `submit_for_review` (status → `submitted_to_staff`, translation requests for
  every non-source locale, audit event).
- Real eligibility checks in `Kiva.Commands.Eligibility`: `partner_owns_draft`,
  `draft_complete`, `required_lc_source_exists`. Command handlers wired for
  `start_loan_application`, `save_loan_draft`, `apply_reuse_suggestion`,
  `submit_loan_for_review` (+ registry entries for the first three).
- `KivaWeb.PartnerLive` (`/partner`) — borrower picker → reuse card → structured
  draft form → review → submit. Every mutation routes through `Kiva.Commands`.
- Seed: `partner@kredo.test` linked to Community Loom Cooperative (sees Rosa).

**Verified**

- `mix test` — 74 tests, 0 failures (draft pre-seed/resume, reuse suggestions,
  **eligibility gating** of submit, cross-partner ownership denial, translation
  jobs queued; PartnerLive start-loan + blocked-incomplete-submit + role guard).

**Notes**

- "Chat-first" is realized as a chat-assisted guided form (the floating
  assistant is present); a fully conversational partner flow can layer on the
  same command handlers. Staff review task = loan status `submitted_to_staff`
  (Phase 7 builds the queue UI + `approve_loan_listing`).

---

## Phase 5 — Lender discovery & lending teams  `observed`

**Delivered**

- Migration `create_teams`: `lending_teams(_lc)`, `lending_team_memberships`,
  `team_posts(_lc)`, `lendings`.
- `Kiva.Teams` — conversational team creation (localized page + translation
  requests + owner membership + audit), localized list/show, message board with
  **on-demand post translation**. `Kiva.Portfolio` — fake lend (advances loan
  funding, records lending, updates team total) + portfolio summary.
- Command handlers: `create_lending_team`, `complete_demo_lend`,
  `post_team_message` (+ registry entries for the latter two).
- Pages: `/teams` (browse + lender portfolio + create form), `/teams/:slug`
  (profile + board + translate-on-demand). “Lend $25” on the loan profile for
  lenders updates funding live. Nav gains Teams.
- Seeds: 3 teams (en/es source), a board post, and a lending so the demo
  lender's portfolio is non-empty.

**Verified**

- `mix test` — 82 tests, 0 failures (team create/LC/membership/translation
  requests, fallback, board post + machine translate; portfolio lend advances
  funding + audit; TeamLive index/create/post).
- HTTP smoke: `/teams` lists teams; `/teams/the-coffee-fund` shows board;
  GraphQL `viewer` works.

---

## Phase 6 — Borrower portal & messages  `observed`

**Delivered**

- Migration `create_messages`: `encouragement_messages(_lc)`.
- `Kiva.Moderation` — rule-based mock moderator (approve / rewrite / block;
  never silently rewrites). `Kiva.Messaging` — on submit: moderate → persist
  source → **machine-translate into the borrower's preferred language** → audit;
  borrower reads approved messages in their own language with a machine/human
  badge. `Kiva.Borrowers` reads for the portal.
- `submit_encouragement_message` command handler. `Lending.list_loans_for_borrower`.
- `KivaWeb.PortalLive` (`/portal`) — borrower's loans (status, funding,
  next repayment) + encouragement messages, all in the borrower's language.
  Encouragement form on the loan profile for lenders (moderated; shows result).
- Seed: Morgan → Rosa encouragement, auto-translated to Spanish.

**Verified**

- `mix test` — 93 tests, 0 failures (moderation cases; approved message
  translated to borrower locale; blocked message not shown; PortalLive renders
  Spanish loan + translated encouragement; role guard; encourage form approve +
  block flashes).

---

## Phase 7 — Admin/staff operations  `observed`

**Delivered**

- `Kiva.Permissions` — direct-grant **outlier** detection (`user_permissions`
  beyond role groups) + `grant_direct`. `Kiva.Translation.list_review_queue/approve/reject`
  across all `*_lc` entity types. `Kiva.Lending.review_queue/approve_listing/request_changes`.
- Real eligibility for `approve_loan_listing`: `partner_review_complete`,
  `risk_summary_present`, `translations_ready_or_fallback_allowed`. Command
  handlers: `approve_translation`, `reject_translation`, `approve_loan_listing`,
  `request_loan_changes` (+ registry entries for the latter two).
- `LoanApplications.submit_for_review` now generates machine `loans_lc` rows
  (the “translation jobs”) and back-fills a risk summary if blank.
- `KivaWeb.AdminLive` (`/admin`) — loan review queue (approve/publish +
  request changes), translation review queue (approve/reject), permission
  outlier dashboard, audit timeline. All actions route through `Kiva.Commands`.
- GraphQL: `loanReviewQueue` (staff/admin), `permissionOutliers` (admin).
- Seed: lender granted a direct high-risk permission (a visible outlier).

**Verified**

- `mix test` — 101 tests, 0 failures (submitted loan → review + translation
  queues; approve listing → fundraising; eligibility blocks a non-submitted
  loan; approve translation clears the queue; outlier detection; AdminLive
  queues + approve actions).

---

## Phase 8 — Trust network demo  `observed`

**Delivered**

- Migration `create_trust`: `trustees(_lc)`, `trust_endorsements(_lc)`,
  `alternative_checks`, `blockchain_attestations`.
- `Kiva.Trust` — localized trust picture per loan (endorsements + checks +
  attestation), and a **mock** integrity attestation (SHA-256 over loan content,
  `mock-attest-v0`, idempotent per loan/type). Trust models stay configurable on
  the loan.
- Loan profile gains a “Trust & verification” section: trust-model explanation,
  localized trustee endorsements, alternative checks (identity/watchlist/
  business viability), and a verified blockchain attestation with proof hash.
- Seed: Mária trustee endorses Sofia's trustee-backed loan (en/es), three passed
  checks, and a verified attestation.

**Verified**

- `mix test` — 104 tests, 0 failures (localized trust picture, idempotent
  attestation, LoanLive trust section renders).
- HTTP smoke: `/loans/sofia-bakery-cart` shows trustee, checks, and a verified
  `mock-attest-v0` attestation; admin GraphQL `permissionOutliers` denied to
  public.

---

## Lender enhancements — StoryTime pass  `observed`

A StoryTime projection on the **lender** plane surfaced nine gaps; all nine were
implemented one-by-one (each tested green). The root finding: the lending loop
was a *line* that stopped at “lend.” It now closes.

1. **Close the loop** — `record_repayment` (partner/staff command) advances the
   schedule + completes the loan; `Portfolio.portfolio_summary` computes each
   lender's proportional **return** + available-to-relend; revealed on the loan
   profile and portfolio. Seed marks two of Rosa's repayments paid.
2. **Impact portfolio** — `/portfolio`: loans touched, returns, repayment
   progress, country/sector distribution, relend nudge (+ nav + dashboard).
3. **Reveal layer** — `notifications` table + `Kiva.Notifications`; lenders are
   notified when a funded loan hits 100% or a repayment arrives (nav bell w/
   unread badge, `/notifications` feed). Fixes the Law-5 silent-state-change gap.
4. **Basket + amount + confirm** — `basket_items` + `Kiva.Basket`,
   `add_loan_to_basket` command, $25/$50/$100 choice, a real confirm step, and
   `/basket` checkout that routes each lend through the registry.
5. **Lend on behalf of a team** — team selector on the lend form; team page shows
   a lending feed + total (surfaces the previously dead `lending_team_id`).
6. **Social proof + urgency** — “N lenders · X days left” on cards/profiles
   (reveal of `lendings` count + seeded `fundraising_ends_at`).
7. **Celebration + receipt** — “You moved Rosa 76% → 78% 🎉” after lending, with
   impact/relend CTAs.
8. **Lender-capable AI** — the assistant lends via chat (`lend $50 to weaving`
   → Command-Mode preview/confirm through the registry), summarizes the
   portfolio (“my impact”), and ranks almost-funded loans.
9. **Honest risk + demo truth** — “Demo — no real money moves; repayments are
   simulated” at the point of lending and on the portfolio.

**Verified** — `mix test` 104 → **125 tests, 0 failures**; strict compile clean;
`mix ecto.reset` rebuilds (lender now has a non-empty notification feed); HTTP:
lender login reaches `/portfolio` (returns + Rosa), `/notifications` (“Repayment
received”), `/basket`.

---

## FractalFlow sync pass  `observed`

The earlier per-phase log lines said models were “now observed,” but only
`identity_access_subsystem.lssd.md` had actually been written — the rest were
untouched seed docs. This pass brought every `docs/fractalflow/*.lssd.md` current
with the real code (one author per subsystem, each grounded in a fresh read).

**Updated / created** (models bumped to `@0.2.0`, revision 2026-06-26):

- `localization_subsystem` — fallback chain, `*_lc` lifecycle, mock translator,
  on-demand translation, staff review queue.
- `loan_lifecycle_subsystem` — full status flow incl. the repayment loop
  (`fundraising → funded → repaying → completed`), 8 commands, proportional return.
- `ai_dialogue_subsystem` — command registry as the single audited mutation path,
  role-scoped GraphQL + Authorize gate, Ask/Command modes incl. lend-via-chat.
- `lending_teams_subsystem` — teams, board + on-demand translation, basket,
  lender impact loop.
- `permissions_trust_subsystem` — permission outliers, audit trail, trustees /
  endorsements / checks / mock attestation.
- `messaging_reveal_subsystem` (**new**) — encouragement moderation+translation,
  and the lender notification reveal layer.
- `kiva_future_demo_product` — built capabilities → `observed`; added
  `lender_impact_loop` and `trust_network_display`.

**Honestly left `asserted` (declared/spec'd but NOT built)** — these double as the
known-gap map, several of which the provider StoryTime pass surfaced:

- `record_disbursal`, `loan.changes_requested_reason`,
  `partner_resumes_changes_requested` (loan_lifecycle).
- `post_borrower_update` + `partner_notification` (messaging_reveal) — the
  provider→lender truth chain that isn't wired yet.
- `revoke_permission`, `manage_permission_group`, `manage_locale`,
  `reset_demo_seed_state` (registry/spec; handlers return `{:not_implemented}`).
- `publish_translation`, `create_translation_jobs` (localization).

No code changed in this pass; the suite remains at 125 tests, 0 failures.

---

## Provider (Partner) StoryTime pass  `observed`

A StoryTime projection on the **provider** plane found nine gaps — most of them
the truth-source the lender's loop depends on (a loan only progresses because the
partner acts). All nine implemented, **with the FractalFlow/AGENTS docs updated
in the same pass** (the doc-fidelity discipline the earlier passes skipped).

1. **Create-a-borrower** — `Borrowers.create_borrower` + `create_borrower`
   command + partner onboarding form (name/country/sector/photo/bio).
2. **Resume sent-back loans + reason** — `request_changes/2` captures a reason;
   PartnerLive shows it with an “Address changes” resume button.
3. **Notify the partner** — `Notifications.notify_partner` on approve/changes;
   `/notifications` + bell now serve partners.
4. **Post borrower updates → reveal to lenders** — `Kiva.Updates` +
   `borrower_updates(_lc)` + `post_borrower_update`; lenders get a notification
   and see the localized update on the loan.
5. **Record disbursal** — `record_disbursal` command advances `disbursal_status`
   + stamps `disbursed_at` and reveals “your loan reached the borrower 💸”.
6. **Borrower photos** — partner sets `image_url`; avatars on cards/profiles.
7/8. **Partner dashboard + repayments-due** — `Lending.partner_overview`;
   PartnerLive shows active loans, total raised, and a repayments-due list with
   one-click record.
9. **Closing outcome** — `post_borrower_update` with `kind: outcome` → a
   completion-story reveal (`loan_outcome 🌱`).

**Docs flipped `asserted` → `observed`** (the gap map shrank): `create_borrower`,
`loan.changes_requested_reason`, `partner_resumes_changes_requested`,
`partner_notification`, the `partner` actor + `borrower_update.post` capability +
`borrower_update.publish` flow + `post_borrower_update` command, `record_disbursal`,
`loan.disbursal_status`; added a `partner_dashboard` view. The `funded_disbursed`
/ `repaying` loan-STATUS values stay `asserted` (still never written — disbursal
lives on the separate `disbursal_status` field). **AGENTS.md** gained a Kiva/LSSD
architecture section.

**Verified** — `mix test` 125 → **142 tests, 0 failures**; strict compile clean;
`mix ecto.reset` rebuilds (now incl. `borrower_updates`, `changes_requested_reason`).

---

## Admin/Staff StoryTime pass  `observed`

A StoryTime projection on the **admin** plane found that the admin could *see*
most things but *act* on almost none — and, crucially, that the demo's loops only
move when the admin moves them. Nine gaps surfaced; the seven worth building:

1. **Demo time machine** — `advance_demo_time` walks every active loan one step
   (fund → disburse → repay → complete), firing all the lender/partner reveals at
   once. The single biggest win for the lender experience: the loops now move.
2. **Revoke permission** — the outlier dashboard is actionable; `revoke_permission`
   handler (`Permissions.revoke_direct/2`) + a Revoke button + audit.
3. **Loan review detail** — `Lending.review_detail/2`: each review card expands to
   localized story/use/risk/repayment, per-locale translation coverage, and a
   computed missing-fields warning. Staff approve with eyes open.
4. **Moderation queue + override** — blocked/flagged encouragement is now PERSISTED
   (held, source + reason) instead of discarded; `approve_message`/`reject_message`
   let staff override (approve translates + delivers). Migration `moderation_reason`.
5. **Analytics dashboard** — `Kiva.Analytics.overview/1`: live aggregates — loans by
   status/country, funding by sector, translation coverage, AI usage.
6. **Reconstructable audit + AI drill-down** — event-type filter + actor/target on
   each audit row; an AI tool-call log with Inspect → full conversation +
   per-call request/response/denial.
7. **Partner/trustee review** — `set_partner_status`/`set_trustee_status`: suspend/
   reactivate from an admin panel (honest note: a status flag, no loan cascade).

**Docs flipped/added `observed`** (in the same pass): `revoke_permission` (command
+ policy + outlier view + flow), `advance_demo_time`, `loan.disbursal_status`,
enriched `admin_review_queue` + filterable `audit_timeline`, new
`ai_tool_call_inspector` (in permissions_trust **and** ai_dialogue), messaging
model rewritten for held-message persistence + `approve_message`/`reject_message`
+ `moderation_queue` view, `partner_trustee_management` view +
`set_partner_status`/`set_trustee_status`, and a net-new `analytics.distribution`
truth + `admin_analytics_dashboard` view. `manage_permission_group` /
`manage_locale` / `reset_demo_seed_state` stay honestly `asserted` (still unbuilt).

**Test infra fix** — diagnosed intermittent "checked out the connection for longer
than 15000ms" failures as sandbox **pool-checkout** contention (`pool_size ==
max_cases`, default 15s checkout timeout), not a logic bug. Fixed in
`config/test.exs` with pool headroom (`schedulers*2 + 8`), `ownership_timeout:
120_000`, and `timeout: 60_000`.

**Verified** — `mix test` 142 → **161 tests, 0 failures**; strict compile clean;
`mix ecto.reset` rebuilds (now incl. `add_moderation_reason`).

---

## Kiva-inspired visual redesign  (page-by-page)

Replaced the default Phoenix/Elixir look with a warm, Kiva-like design system,
verified page-by-page with headless-Chrome screenshots.

**Design system (`assets/css/app.css`, `root.html.heex`):**
- DaisyUI light theme recolored — leaf-green `primary`, coral `accent`, forest
  `secondary`, warm-cream `base`, deep-green text; softer radii (box 1rem) +
  1px borders + a subtle global card shadow. Dark theme's brand colors greened too.
- Fonts: **Fraunces** (serif display, via `h1`/`h2`/`.font-display`) + **Inter**
  (body), loaded from Google Fonts. Default theme pinned to `light`.

**Conventions** (reuse these for any new page):
- Page title: `<h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">`.
- Cards are photo-forward: a 3:2 `<figure>` with the borrower/team image, or a
  `from-primary/20 to-accent/20` gradient with the **first initial** in Fraunces
  when no image exists (all demo borrowers — none have photos).

**Pages touched:** shell (sticky branded nav + forest 3-col footer), home (hero +
featured loans + how-it-works + demo-accounts collapse), loan index/show, the
shared `loan_card`, portfolio, basket, teams index/show, partner workspace + show,
portal, notifications, admin, login (card-wrapped “Welcome back” + one-click demo
accounts), FAQ. The floating chat widget inherits the theme.

**Verified** — strict compile clean; **164 tests, 0 failures**; `mix ecto.reset`
rebuilds. Screenshots confirmed home, loans, loan detail, teams, partner, login,
and FAQ; auth-gated pages share the same shell/components and pass their LiveView
tests. Test copy assertions updated where the home headline changed.

---

## Full localization — no English outside user content  (es/de/fr/nl)

The UI was only ~21% translated (149/188 `.po` strings empty) and many runtime
strings weren't translatable at all. Closed every gap:

**Made runtime English translatable** (`view_helpers.ex`, `i18n_strings.ex`):
- `country_name` / `trust_model_label` / `disbursal_label` /
  `trust_model_explanation` now run their result through `Gettext.gettext/2`.
- New `status_label/1` (humanize + translate) replaces every raw `{x.status}`
  render (loan/repayment/moderation/partner/trustee/translation status).
- Notifications render via TYPE: `notif_title/1` + `notif_body/1` (language-neutral
  storage, localized at read time) instead of stored English `{n.title}`/`{n.body}`.
- `KivaWeb.I18nStrings.registered/0` lists all such literals as real `gettext(...)`
  calls so `mix gettext.extract` captures them.

**Filled the catalogs** (`priv/gettext/{es,de,fr,nl}`): extract+merge → ~300
 msgids; translated every empty/fuzzy string via a local LLM (zero Claude
tokens) through an Expo-based `.po` round-trip (`translate_po.exs`). 0 empty left.

**Filled the seed content** — every `*_lc` table now covers all 5 locales
(was en + partial es): all 3 loans, activities, partners, FAQs, trustee,
endorsement. Loan stories + partner/FAQ/trust copy were hand-translated
(the local model mangled the centerpiece content — e.g. CJK characters in a German
title), short taxonomy + bulk UI strings via a local LLM.

**Result:** on ES/DE/FR/NL, chrome, badges, statuses, notifications, loan detail,
FAQ, partner and trust content are all in-language. The only English left is
user-generated content (team posts, encouragement) — the explicit exception.
Verified with `?locale=` screenshots (ES + DE loan pages, FR FAQ). 164 tests pass.
