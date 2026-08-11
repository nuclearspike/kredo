<!--
Canonical-For: .
Status: ACTIVE
-->

# FractalFlow — Kredo (Kiva Future Demo) Product

Top-level product model for Kredo (built under the working title "Kiva Future
Demo"; surface-rebranded 2026-08-10 — see @decision.rebrand_kredo). Capabilities now realized in the
Elixir/Phoenix/LiveView code (Phases 0–8 plus the lender StoryTime pass, 125 tests
green) are marked `observed`; the remaining actors/modules stay `asserted` as the
declared product scaffolding around them.

2026-08-10: grammar upgrade to the current LSSD spec — product outcomes for the
two stated pillars, module/system wiring, the staff first-person journey (the
one dashboard no single subsystem owns), an initiative ledger carrying the four
audit rulings' mandated work, and the audit itself as a source artifact. The
four dashboard rulings moved to their owning subsystem contracts (pointer
below); the staff journey here is `practitioner_unvalidated`.

```lssd
model kiva_future_demo@0.3.0 {
  namespace: "kiva.future_demo"
  revision: "2026-08-10"
  sourceSnapshot: { user_request: "chat-2026-06-26" }
  status: observed
  confidence: 0.9
}

system kiva.future_demo {
  label: "Kredo — multilingual chat-first lending network demo"
  contains: [@module.localization, @module.loan_lifecycle, @module.ai_dialogue, @module.trust_network, @module.lending_teams, @module.admin_ops, @module.messaging_reveal, @module.identity_access]
  status: asserted
  confidence: 0.90
  summary: "Multilingual chat-first lending network demo with borrowers, lenders, partners, staff, trustees, teams, localization, and AI dialogue."
}

artifact dashboard_first_person_audit {
  kind: "StoryTime first-person audit (v1.12) of the four logged-in dashboards"
  path: "docs/storytime/dashboard_first_person_audit_2026-08-10.md"
  status: confirmed
  confidence: 1.0
  metadata: { note: "Code read + rendered cold-reads of /portal, /portfolio, /partner, /admin; carries the derived question stacks, severity findings H1-H6/M1-M6/L1-L4, and the owner's Q1-Q4 rulings. Seed source for every 2026-08-10 first-person contract entry." }
}

# --- Product-pillar outcomes (2026-08-10) -------------------------------
outcome outcome.actor.native_language_everywhere {
  label: "Every actor reads and is read in their own language, with honest badges when a machine or fallback stands in"
  steps_max: 1
  vocabulary: actor
  summary: "The localization pillar as an outcome: zero steps to receive your language (it arrives with the session), one step to change it. Currently broken at first login by session-locale precedence (@finding.localization.locale_precedence_defeats_default, audit H2)."
  status: asserted
  confidence: 0.9
}

outcome outcome.actor.ask_and_act_in_place {
  label: "Any actor asks about what they see and acts on it from where they stand — chat, buttons, and agents sharing one command registry"
  steps_max: 2
  vocabulary: actor
  summary: "The chat-first pillar as an outcome: ask (one step), act via preview -> confirm (two steps), never leaving the page. Currently unreachable — the launcher is dark on every surface (@decision.restore_chat_launcher, audit H1)."
  status: asserted
  confidence: 0.9
}

outcome outcome.staff.decisions_cleared {
  label: "Staff sees every decision waiting on them — count, size, oldest — and clears each with its evidence in the row"
  steps_max: 1
  vocabulary: actor
  summary: "One step per verdict: the row itself carries what the verdict needs (source ⇄ target for translations, reason context for held messages). A queue that demands a second hop to gather evidence fails the budget (audit H4)."
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
}

actor actor.borrower {
  label: "Borrower"
  status: asserted
  confidence: 0.95
}

actor actor.lender {
  label: "Lender"
  status: asserted
  confidence: 0.95
}

actor actor.partner {
  label: "Partner"
  status: asserted
  confidence: 0.95
}

actor actor.staff {
  label: "Staff/Admin"
  status: asserted
  confidence: 0.95
  summary: "Embodied 2026-08-10 for the /admin first-person layer (audit persona Jordan). Lexicon and monologue are DRAFTED from the audit's cold-reads — not practitioner-harvested."
  domainVocabulary: ["queue", "waiting", "oldest", "held messages", "outlier"]
  lexicon: [
    { contract_term: "review queue counts", actor_term: "%{n} decisions waiting", register_person: "second person, operational en", banned: false },
    { contract_term: "moderation_status blocked/flagged", actor_term: "held messages", register_person: "second person", banned: false },
    { contract_term: "direct permission grant", actor_term: "permission outlier — someone holding power outside their role", banned: false },
    { contract_term: "unformatted counts (1035121)", actor_term: "1,035,121", banned: true, homonym_warning: "raw numerals read as machine output (audit M5; num/2 exists and goes unused)" },
    { contract_term: "analytics tables as the page lead", actor_term: "(system pulse — folded below the queues)", banned: true }
  ]
  lexiconProvenance: "Drafted 2026-08-10 from the dashboard audit; verbatim_sentences empty until a real reviewer narrates"
  knowledgeBoundary: {
    availableNow: ["Queue counts", "Each queue item's content once opened", "Audit trail and AI call log"]
    unavailableYet: ["Queue aging (truth not derived — @admin.queue_aging)", "Translation source text from the queue row (audit H4)"]
  }
  perceptualChannels: [visual, textual]
  representativeWork: "Morning decision sweep: 105 translations, 2 held messages, 1 permission outlier, 0 loans (audit persona Jordan)"
  interruptionAndTimeConstraints: ["Queue work interleaves with everything else; must resume mid-queue without loss"]
  authorityAndRiskBoundary: ["Verdicts on listings, translations, held messages; revoking permissions is admin-only high-risk"]
  evidenceLevel: agent_walked
}

actor actor.trustee {
  label: "Trustee"
  status: asserted
  confidence: 0.80
}

actor actor.ai_agent {
  label: "Page-aware AI assistant"
  status: asserted
  confidence: 0.90
}

module module.localization {
  label: "Localization and language content"
  contains: [@localization.core, @localization.translation]
  status: asserted
  confidence: 0.95
}

module module.loan_lifecycle {
  label: "Loan lifecycle"
  contains: [@loan.lifecycle]
  status: asserted
  confidence: 0.95
}

module module.ai_dialogue {
  label: "AI dialogue"
  contains: [@ai.dialogue]
  status: asserted
  confidence: 0.95
}

module module.trust_network {
  label: "Trust network and risk"
  contains: [@trust.network]
  status: asserted
  confidence: 0.90
}

module module.lending_teams {
  label: "Lending teams"
  contains: [@lending_teams.core]
  status: asserted
  confidence: 0.90
}

module module.admin_ops {
  label: "Admin and staff operations"
  contains: [@permissions.core, @audit.trail, @provenance.core]
  status: asserted
  confidence: 0.90
}

module module.messaging_reveal {
  label: "Messaging, moderation, and reveals"
  contains: [@messaging.reveal]
  status: asserted
  confidence: 0.95
  metadata: { note: "Added 2026-08-10 — the subsystem contract existed without a product-module anchor." }
}

module module.identity_access {
  label: "Identity and access"
  contains: [@identity.access]
  status: asserted
  confidence: 0.95
  metadata: { note: "Added 2026-08-10 — the subsystem contract existed without a product-module anchor." }
}

capability capability.multilingual_public_site {
  label: "Fully multilingual public site"
  servesOutcome: @outcome.actor.native_language_everywhere
  status: observed
  confidence: 0.95
  summary: "The full public site, footer, chrome, and content switch between en/de/es/fr/nl via the globe dropdown; gettext chrome catalogs plus per-entity *_lc fallback resolver."
}

capability capability.chat_first_navigation {
  label: "Chat-first page-aware navigation"
  servesOutcome: @outcome.actor.ask_and_act_in_place
  status: observed
  confidence: 0.95
  summary: "Every LiveView page exposes the floating AI chat (KivaWeb.ChatLive, which replaced KivaWeb.ChatComponent in commit 044f9b2): Ask Mode answers via role-scoped GraphQL, Command Mode previews registered commands and proposes an explicit confirm."
}

capability capability.partner_chat_loan_application {
  label: "Partner chat-first loan application"
  servesOutcome: @outcome.partner.loan_listed
  status: observed
  confidence: 0.95
  summary: "PartnerLive + Kiva.LoanApplications: borrower reuse suggestions, draft loans, submit-for-review with translation jobs, all mutating through Kiva.Commands."
}

capability capability.borrower_native_language_portal {
  label: "Borrower native-language portal"
  servesOutcome: @outcome.borrower.money_status_known
  status: observed
  confidence: 0.95
  summary: "PortalLive renders the borrower's loans and moderated, machine-translated encouragement messages in their preferred language with honest machine/human badges."
}

capability capability.lender_team_creation {
  label: "Conversational lending team creation"
  servesOutcome: @outcome.lender.lend_together
  status: observed
  confidence: 0.90
  summary: "Kiva.Teams + TeamLive: localized team creation, owner membership, message board with on-demand post translation, all audited through the command registry."
}

capability capability.lender_impact_loop {
  label: "Lender impact loop"
  servesOutcome: @outcome.lender.principal_back_to_relend
  status: observed
  confidence: 0.95
  summary: "lend -> fund -> repay -> relend, with reveals, basket, teams, and impact portfolio. Kiva.Portfolio / Kiva.Basket / Kiva.Notifications: $25/$50/$100 basket checkout through the registry, lend-on-behalf-of-a-team, record_repayment closing the schedule, proportional repayments + available-to-relend on /portfolio, notification bell on funding/repayment, celebration receipt, and lender-capable AI ('lend $50 to weaving', 'my impact'). Since 2026-07-07 /portfolio is a full impact dashboard: repaid ring, cumulative scheduled-vs-received repayment chart, and status/country/sector/partner slice-and-dice (see loan_lifecycle_subsystem @portfolio_impact)."
}

capability capability.trust_network_display {
  label: "Trust network display"
  servesOutcome: @outcome.lender.trust_verified
  status: observed
  confidence: 0.95
  summary: "Loan profile 'Trust & verification' section (Kiva.Trust): trust-model explanation, localized trustee endorsements, alternative checks (identity/watchlist/business viability), and a verified mock SHA-256 blockchain attestation with proof hash."
}

view view.global_language_dropdown for @capability.multilingual_public_site {
  label: "Global language dropdown"
  status: observed
  confidence: 0.95
  affordances: [select_locale]
  reveals: [@truth.user.selected_locale]
  commands: [set_locale]
}

truth truth.user.selected_locale {
  label: "Selected UI locale"
  lifetime: session
  authority: { mode: human, ref: @actor.lender }
  visibility: [public, borrower, lender, partner, staff, system]
  status: observed
  confidence: 0.95
}

# --- 2026-07-26: capabilities shipped after the 06-26 snapshot ----------

capability capability.developer_portal {
  label: "Developer portal with OAuth-client apps, API keys, and tri-surface docs"
  servesOutcome: @outcome.developer.integrated
  status: observed
  confidence: 0.9
  summary: "Self-enabled developer capability: /developer dashboard, OAuth-client apps + API keys, GraphiQL, and machine-readable docs incl. GET /developers/agents.md (an agent capability manifest generated from the same registry the UI uses). Shipped in commit 5efb1f1; subsystem contract skeleton authored 2026-08-10 (docs/fractalflow/developer_compat_subsystem.lssd.md, resolving @question.docs.developer_subsystem_contract)."
}

# --- 2026-08-10: dashboard first-person audit — product rulings ----------
# Source: @dashboard_first_person_audit (Q1–Q4, answered by the product
# owner). Restructured into current decision_record grammar and MOVED to the
# owning subsystem contracts on 2026-08-10 (node ids unchanged):
#   decision.encouragement_sender_reveal -> messaging_reveal_subsystem.lssd.md
#   decision.partner_bulk_collections    -> loan_lifecycle_subsystem.lssd.md
#   decision.lender_risk_details_page    -> loan_lifecycle_subsystem.lssd.md
#   decision.restore_chat_launcher       -> ai_dialogue_subsystem.lssd.md
# Each record `mandates` an initiative in the ledger below — the decision
# records the choice; the initiative records whether it happened.

# --- 2026-08-10: the staff journey (the one dashboard no subsystem owns) --

truth admin.queue_aging {
  label: "Per-queue oldest-item age (how long the oldest waiting decision has waited)"
  lifetime: run
  authority: { mode: derived, ref: @module.admin_ops }
  visibility: [staff, system]
  status: asserted
  confidence: 0.85
  sourceRefs: [@dashboard_first_person_audit]
  metadata: { note: "Derivable from queue rows' inserted_at; forced backward by the staff stack entry 1 and the header transcription target (audit: counts exist, aging absent). Spans loan review, translation review, held messages, permission outliers." }
}

convergence_point cp.admin.morning_decisions {
  label: "The staff morning: four decision queues meet as one moment — what awaits me, how much, how old"
  status: candidate
  confidence: 0.85
  sourceRefs: [@dashboard_first_person_audit]
  metadata: {
    constituents: ["@admin_review_queue (loan lifecycle)", "@translation_review_queue (localization)", "@moderation_queue (messaging)", "@permission_outlier_dashboard (permissions)"],
    steps_budget: "0 steps to the answer (header strip); 1 step per verdict",
    note: "candidate: model-derived from the 2026-08-10 audit, not practitioner-recognized. Today the queues render BELOW analytics with no shared header (audit M5); the convergence demands the transcription-target strip lead the page."
  }
}

story story.staff.decision_sweep for @actor.staff {
  label: "Jordan's morning: what needs my decision today"
  servesOutcome: @outcome.staff.decisions_cleared
  practitionerGate: practitioner_unvalidated
  evidenceLevel: agent_walked
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
  summary: "The audited /admin leads with raw analytics tables while the queues follow (audit M5) — machine-first inversion. This journey converges the four queues (@cp.admin.morning_decisions) under one answering header and equips each verdict in its row."
  screenplay: {
    id: "SPL-admin-habitual"
    mindset_variant: habitual
    register: "@actor.staff lexicon — second person, operational en"
    beats: [
      { stage: @stage.admin.queue_scan, screen_says: "9 decisions waiting — 0 loans · 105 translations (oldest 3 d) · 2 held messages · 1 permission outlier.", actor_thinks: "Translations first — that oldest one has waited three days.", actor_does: "Opens the translation queue.", screen_replies: "105 translations, grouped by loan — source ⇄ target, method and confidence on every row.", forces_truths: [@admin.queue_aging] },
      { stage: @stage.admin.unequipped_verdict, screen_says: "(today) 105 flat rows — truncated target-only snippet, Approve/Reject.", actor_thinks: "I can't see the source text — I can't judge these from here.", actor_does: "Asks for the source alongside the target.", screen_replies: "(the evidence exists — @lc.source_locale — the row just doesn't carry it; audit H4)", forces_truths: [] },
      { stage: @stage.admin.queue_scan, screen_says: "Anything unusual: 1 permission outlier (high risk first) · 3 denied AI calls overnight.", actor_thinks: "Who granted that, and why?", actor_does: "Opens the outlier row.", screen_replies: "grant: <email> · <permission> · granted by <admin> · reason on file — Revoke available.", forces_truths: [] }
    ]
    transcribed_keys: []
    note: "Stub (v1.12). The headline beat is the audit's verbatim transcription target (en source). Bulk approve of machine translations above threshold is deliberately NOT voiced as available — it is unruled (@question.localization.bulk_translation_approval)."
  }
}

stage stage.admin.queue_scan in @story.staff.decision_sweep {
  label: "Admin open — what awaits my decision?"
  interiorMonologue: {
    habitual: ["What's waiting on me, how much, and how old is the oldest?", "Anything weird overnight?"]
    returning_after_away: ["What piled up? Worst first."]
  }
  monologueProvenance: "Drafted (model-derived from the audit cold-read); no practitioner verbatims yet"
  questionStack: [
    { q: "What awaits my decision — how many, how big, how old?", answeredBy: [@ask.admin.decision_queue, @admin.queue_aging], today: "queues render BELOW analytics; counts exist, aging absent (audit M5)" },
    { q: "Anything anomalous?", answeredBy: [@permission.direct_grant, @ai.tool_call], today: "outliers and denied-AI-calls exist further down; no signal in headers (audit)" },
    { q: "System pulse — how is the product doing?", answeredBy: [@analytics.distribution], today: "currently LEADS the page as raw tables; belongs folded at the bottom, formatted (audit M5)" }
  ]
  transcriptionTargets: ["en-source (audit verbatim): '9 decisions waiting — 0 loans · 105 translations (oldest 3 d) · 2 held messages · 1 permission outlier.'"]
  actorCanKnow: ["Queue counts", "Outlier grants ordered by risk", "Denied AI calls with reasons"]
  actorCannotKnowYet: ["Queue aging (@admin.queue_aging pending)", "Translation source text from the row (audit H4)"]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.85
}

decision decision.admin.clear_translations at @stage.admin.queue_scan {
  label: "Judge waiting translations"
  resolvesTo: [@approve_translation, @reject_translation]
  exposure: primary
  status: observed
  confidence: 0.9
}

decision decision.admin.clear_loan_reviews at @stage.admin.queue_scan {
  label: "Approve or bounce submitted loans"
  resolvesTo: [@approve_loan_listing, @request_loan_changes]
  exposure: primary
  status: observed
  confidence: 0.9
}

decision decision.admin.clear_held_messages at @stage.admin.queue_scan {
  label: "Rule on held encouragement messages"
  resolvesTo: [@approve_message, @reject_message]
  exposure: primary
  status: observed
  confidence: 0.9
}

decision decision.admin.review_outliers at @stage.admin.queue_scan {
  label: "Review permission outliers (revoke or note as expected)"
  resolvesTo: [@revoke_permission]
  exposure: contextual
  status: observed
  confidence: 0.9
}

stage stage.admin.unequipped_verdict in @story.staff.decision_sweep {
  label: "Failure path: the queue demands a verdict it doesn't equip"
  summary: "Translation review offers Approve/Reject against a truncated target-only snippet — no source text, confidence, method, or owning loan (audit H4; Law 18 violation live today). The reviewer cannot actually review from the surface that demands the verdict."
  interiorMonologue: {
    something_wrong: ["105 of these and I can't see the source — I'd be guessing.", "Approving blind is worse than the backlog."]
  }
  questionStack: [
    { q: "What does the source say, and how was this produced?", answeredBy: [@ask.admin.translation_evidence], today: "the truths exist (@lc.source_locale, method in @lc.translation_status); the row hides them" }
  ]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.85
}

decision decision.admin.demand_evidence at @stage.admin.unequipped_verdict {
  label: "See the evidence before ruling"
  resolvesTo: [@ask.admin.translation_evidence]
  exposure: primary
  status: asserted
  confidence: 0.85
}

ask ask.admin.decision_queue {
  label: "What awaits my decision — how many, how big, how old?"
  visibility: [staff]
  provenance: "staffReviewQueueCount GraphQL field + the four queue list functions; the aging dimension needs @admin.queue_aging (pending)"
  status: asserted
  confidence: 0.85
}

ask ask.admin.translation_evidence {
  label: "Show me enough to judge this translation: source ⇄ target, method, confidence, owning loan"
  visibility: [staff]
  provenance: "All truths exist (@lc.source_locale carries source text; @lc.translation_status carries machine/human method); the queue surface renders only a truncated target snippet (audit H4) — this ask is the evidence contract for the row"
  status: asserted
  confidence: 0.9
}

intent intent.admin.whats_waiting for @actor.staff {
  label: "What needs my decision today?"
  mode: ask
  phrasings: [
    "What needs my decision today?"
    "What's waiting on me?"
    "Anything weird overnight?"
  ]
  resolvesTo: [@ask.admin.decision_queue]
  servesOutcome: @outcome.staff.decisions_cleared
  availableAt: [@stage.admin.queue_scan]
  maturity: candidate
  status: asserted
  confidence: 0.8
}

# --- 2026-08-10: publication prep (GitHub feasibility follow-through) ----------

decision_record decision.rebrand_kredo {
  decision: "Surface rebrand to Kredo for public release: header/footer/titles, assistant name, developer-docs headings, and gettext catalogs renamed (en/es/de/fr/nl translations transplanted); demo accounts moved from kiva.org / demo.kiva addresses to kredo.test with an idempotent legacy-email migration in priv/repo/seeds.exs. The internal Kiva.*/KivaWeb.* module namespace and the Kiva-compatibility API surface names are deliberately unchanged (they model the real external API; README carries the non-affiliation disclaimer). Planning docs under docs/prd keep the original working title as historical record."
  state: active
  authority: { mode: human, owner: "Paul Ericksen" }
  decidedAt: "2026-08-10"
  alternatives: ["Publish under the Kiva Future Demo working title", "Rename the internal module namespace too"]
  consequences: ["Contracts state the product name as Kredo; internal kiva.* namespaces and Kiva.* modules stay", "Legacy demo emails migrate idempotently on seed"]
  revisitWhen: ["Trademark/affiliation feedback", "A real fork diverges from the Kiva-compat surface"]
  supersedes: []
  status: confirmed
  confidence: 1.0
  metadata: { implemented: "observed in the published tree (commit 21beb3d); record restructured to current grammar 2026-08-10, content unchanged" }
}

capability capability.scale_generator {
  label: "Parameterized offline demo-data generator (any loan count)"
  preservesOutcome: "Demo credibility at scale — every dashboard journey stays honest against 77K-loan / 1.4K-lending worlds without shipping data"
  status: observed
  confidence: 0.95
  summary: "scripts/loan_gen fabricates FK-consistent demo worlds at any scale (build_csv.py --loans/--users, build_1m.py --count) from the committed 208-template 5-locale text pool — no LLM needed; resolves id bases and slug->id maps live from the target database (--db), honors the $25-unit lending invariants (loans/lendings CHECK constraints), and bulk-loads via psql copy (load.sh / load_1m.sh, team lifetime totals recomputed). Output CSVs are gitignored: the repo ships the generator, never the data. Smoke-verified end-to-end against a scratch DB 2026-08-10."
}

capability capability.listing_provenance {
  label: "Auditor-grade listing provenance (fabricated for the demo)"
  servesOutcome: @outcome.staff.authenticity_traced
  status: observed
  confidence: 0.95
  summary: "Append-only authenticity trail per listing — photo capture (app/version/device/GPS), consent, identity verification, site visits, story authorship, AI rewording (named model + template), translation method (machine/template/human with names, dates, places), review/approval events, and visibility changes — with sha256 derivation chains that verify. Staff/admin see the full timeline on the loan profile; wider visibility is an open product decision. See docs/fractalflow/provenance_subsystem.lssd.md."
}

capability capability.kiva_api_compat {
  label: "Kiva-compatible external API (legacy REST v1 + GraphQL mirror + OAuth)"
  status: observed
  confidence: 0.9
  summary: "Replicates the real Kiva public surfaces so legacy clients (e.g. KivaLens) run unchanged: /v1 REST (loans search/newest/detail/lenders/journal_entries, partners, lenders, teams, templates, my/*), a root /graphql mirroring api.kiva.org, and /oauth authorize+token. Shipped in commits 375e99d..044f9b2."
}

evidence evidence.compat.surface_tests {
  kind: observation
  occurredAt: "2026-07-07"
  subject: @capability.kiva_api_compat
  method: "Compat test suites exercising the v1 REST endpoints, the Kiva GraphQL mirror, and OAuth flows"
  value: { suites: ["test/kiva_web/kiva_v1/rest_test.exs", "test/kiva_web/kiva_graphql/schema_test.exs"], full_suite: "mix test 260/260 green 2026-07-07" }
  provenance: { commits: ["375e99d", "044f9b2"] }
  integrity: { verification: "Suites green at commit time" }
  scope: ["Endpoints and fields exercised by the compat suites"]
  status: observed
  confidence: 0.95
}

decision_record decision_record.compat.qualify_tested_scope {
  decision: "Treat the Kiva-compat surface as qualified only for the endpoints, fields, and flows the compat suites exercise, serving demo data; make no parity claim beyond that scope."
  state: active
  authority: { mode: human, owner: "Paul Ericksen" }
  decidedAt: "2026-07-26"
  basedOn: [@evidence.compat.surface_tests]
  alternatives: ["Claim full api.kivaws.org parity", "Leave the surface unqualified prose"]
  consequences: ["Agents may rely on the tested scope", "Anything outside the suites stays explicitly unqualified until tested"]
  revisitWhen: ["Compat suites gain or lose coverage", "A new legacy client is targeted"]
  supersedes: []
  status: confirmed
  confidence: 0.95
}

capability_qualification capability_qualification.kiva_api_compat {
  qualificationState: conditional
  capability: @capability.kiva_api_compat
  decision: @decision_record.compat.qualify_tested_scope
  qualifiedScope: ["The v1 REST endpoints, GraphQL fields, and OAuth flows exercised by the compat test suites, serving demo data"]
  excludedScope: ["Real-Kiva endpoints not implemented in the router", "Byte-level parity with api.kivaws.org beyond what the suites assert", "Production traffic, rate limits, and real credentials"]
  gates: ["rest_test.exs and kiva_graphql schema_test.exs green", "A legacy client (KivaLens) drives the surface without modification — demo-verified, not continuously tested"]
  basedOn: [@evidence.compat.surface_tests]
  validFrom: "2026-07-07"
  requalifyWhen: ["Router/controller/schema changes under /v1, /graphql, or /oauth", "A new legacy client is targeted"]
  knowledge: {
    scope: ["kredo Kiva-compat surface as of commit 044f9b2"]
    evidence: [@evidence.compat.surface_tests]
    owner: "Paul Ericksen"
    learnedAt: "2026-07-07"
    invalidatedBy: ["Compat suite regression", "Kiva upstream API semantics change the target"]
    supersedes: []
  }
  status: confirmed
  confidence: 0.9
}

question question.docs.developer_subsystem_contract on @capability.developer_portal {
  questionType: open_question
  ask: "Author a FractalFlow subsystem contract for the developer portal + Kiva-compat surface (built 06-27/28, after the contract snapshot), or defer to the next substantive change under the touched-story rule?"
  whyItMatters: "It was the only shipped subsystem with no contract; agents reverse-engineered it from the router and tests."
  owner: "Paul Ericksen"
  neededBy: "Next substantive change to /developer, /v1, /graphql, or /oauth"
  blocking: []
  resolveWith: ["Either author docs/fractalflow/developer_compat_subsystem.lssd.md or record the explicit decision to document on next touch"]
  resolution: "RESOLVED 2026-08-10: skeleton authored (docs/fractalflow/developer_compat_subsystem.lssd.md, asserted — no fresh code read); grow it under the touched-story rule on the next /developer or compat change."
  knowledge: {
    scope: ["docs/fractalflow coverage"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-07-26"
    invalidatedBy: ["The contract is authored"]
    supersedes: []
  }
  status: confirmed
  confidence: 0.9
}

# --- 2026-08-10: initiative ledger — work the audit rulings mandate ------
# The decision records the choice; the initiative records whether it
# happened. All four originate from owner rulings Q1-Q4 in
# @dashboard_first_person_audit and are committed, not started.

initiative product.sender_reveal {
  title: "Encouragement sender reveal via public profile + borrower thank/acknowledge return edge"
  servesOutcome: "Borrowers see who encouraged them (when the sender is public) and can say thanks — the missing return edge of the encouragement reveal"
  owner: "Paul Ericksen"
  originKind: decision_mandate
  originRecordedAt: "2026-08-10"
  originRefs: ["@decision.encouragement_sender_reveal (messaging contract)", "docs/storytime/dashboard_first_person_audit_2026-08-10.md Q1"]
  definitionOfDone: ["user.profile_public lands in the schema with a lender-controlled toggle (default private)", "Borrower portal renders sender name/avatar + date + loan for public senders; anonymous presentation for private senders stands", "Thank/acknowledge return edge registered as a command with a reveal to the sender", "Experience tests cover public vs private sender rendering"]
  status: committed
  lastActivity: "2026-08-10"
}

initiative product.bulk_collections {
  title: "Partner day-batch collections: 'record today's collections' with preview -> confirm through the registry"
  servesOutcome: "@outcome.partner.day_collected within its steps_max 2 at 1,992-due scale"
  owner: "Paul Ericksen"
  originKind: decision_mandate
  originRecordedAt: "2026-08-10"
  originRefs: ["@decision.partner_bulk_collections (loan lifecycle contract)", "docs/storytime/dashboard_first_person_audit_2026-08-10.md Q2"]
  definitionOfDone: ["Day-batch selection surface leading the partner workspace's Today block", "Bulk preview -> confirm path through Kiva.Commands (no chat-only or button-only shortcut)", "Rows reveal due date, amount, overdue aging (@repayment_schedule.item_terms, @repayment.arrears_aging)", "Per-loan recording remains as the exception path", "Exercised against generated 1,992-due scale"]
  status: committed
  lastActivity: "2026-08-10"
}

initiative product.risk_details_page {
  title: "Lender risk & repayment details page — losses, arrears, (excluded or modeled) FX, sliced by country and partner"
  servesOutcome: "@outcome.lender.principal_back_to_relend — the lender relends because the trust question is answered, not despite it"
  owner: "Paul Ericksen"
  originKind: decision_mandate
  originRecordedAt: "2026-08-10"
  originRefs: ["@decision.lender_risk_details_page (loan lifecycle contract)", "docs/storytime/dashboard_first_person_audit_2026-08-10.md Q3"]
  definitionOfDone: ["Derived truths land: @loan.loss_attribution, @repayment.arrears_aging", "@question.portfolio.fx_modeling resolved (modeled FX truth or explicit all-USD exclusion note on the page)", "Dedicated details surface sliced by country and partner", "Portfolio hero gains one honest risk line linking to it"]
  status: committed
  lastActivity: "2026-08-10"
}

initiative product.restore_chat {
  title: "Restore the chat launcher on every live_chat page (regression, not a decision)"
  servesOutcome: "@outcome.actor.ask_and_act_in_place — the product's signature architecture reachable again from every surface"
  owner: "Paul Ericksen"
  originKind: decision_mandate
  originRecordedAt: "2026-08-10"
  originRefs: ["@decision.restore_chat_launcher (ai dialogue contract)", "docs/storytime/dashboard_first_person_audit_2026-08-10.md Q4 + H1"]
  definitionOfDone: ["live_render(KivaWeb.ChatLive) restored in root.html.heex", "Launcher present on every page passing live_chat={true}", "Regression test: FAB present on every live_chat page (audit Law-16 note)"]
  status: committed
  lastActivity: "2026-08-10"
}
```
