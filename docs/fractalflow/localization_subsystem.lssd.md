<!--
Canonical-For: lib/kiva/localization, lib/kiva/translation.ex, lib/kiva_web/plugs/set_locale.ex, priv/gettext
Status: ACTIVE
-->

# FractalFlow — Localization Subsystem

Models the implemented localization subsystem: the supported-locale truth and `requested -> en` fallback chain, the `*_lc` sidecar pattern, the translation lifecycle with a mock machine translator, on-demand long-tail translation, `translation_requests` tracking, and the staff translation review queue.

2026-07-26: adopted the durable-knowledge grammar — the gettext fuzzy-autofill incident and its heuristic, the sidecar public-resolution pattern with its class adoption, and the catalog-repair recipe with its two 2026-07-07 production runs.

2026-08-10: grammar upgrade + the dashboard audit's H2 finding — session
locale write-back shadows the account default at first login, defeating the
native-language pillar (evidence + finding below). set_locale declared as the
registered command it already is; staff translation verdict commands lifted
into full grammar for the admin decision-sweep journey.

```lssd
model kiva.localization@0.4.0 {
  namespace: "kiva.localization"
  revision: "2026-08-10"
  status: observed
  confidence: 0.9
}

module localization.core {
  label: "Localization Core"
  status: observed
  confidence: 0.95
  metadata: { source: "lib/kiva/localization.ex", note: "Owns supported set, fallback chain, locale-aware money formatting." }
}

module localization.translation {
  label: "Translation lifecycle + mock machine translator"
  status: observed
  confidence: 0.95
  metadata: { source: "lib/kiva/translation.ex", mock_model: "mock-mt-v0" }
}

actor actor.partner {
  label: "Partner authoring source content"
  status: observed
  confidence: 0.9
}

actor actor.staff {
  label: "Staff/admin reviewing translations"
  status: observed
  confidence: 0.95
}

actor actor.ai_agent {
  label: "Mock machine translator (mock-mt-v0)"
  status: observed
  confidence: 0.95
}

actor actor.visitor {
  label: "Public reader requesting a locale / triggering on-demand translation"
  status: observed
  confidence: 0.9
}

truth locale.supported_codes {
  label: "Supported locale codes (truth + default)"
  lifetime: system
  authority: { mode: service, ref: @localization.core }
  visibility: [public, internal]
  status: observed
  confidence: 0.95
  metadata: { codes: ["en", "de", "es", "fr", "nl"], default: "en", ref: "Kiva.Localization.supported_locales/0" }
}

truth locale.fallback_chain {
  label: "Fallback chain for a requested locale (requested -> en)"
  lifetime: system
  authority: { mode: service, ref: @localization.core }
  visibility: [public, internal]
  status: observed
  confidence: 0.95
  metadata: { rule: "normalize unsupported -> en; en -> [en]; other -> [other, en]", ref: "Kiva.Localization.fallback_chain/1" }
}

truth lc.source_locale {
  label: "Source LC row for an entity (is_source flag + source_locale_code)"
  lifetime: system
  authority: { mode: human, ref: @actor.partner }
  visibility: [partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { schema: "faq_entries_lc / loans_lc / team_posts_lc / encouragement_messages_lc", default_source: "en" }
}

truth lc.translation_status {
  label: "Per-LC-row translation workflow status"
  lifetime: system
  authority: { mode: service, ref: @localization.translation }
  visibility: [partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { values: ["draft", "machine", "needs_review", "approved", "published", "stale", "rejected", "source"], display_eligible: ["source", "published", "approved", "machine", "needs_review"] }
}

truth lc.source_hash {
  label: "Stable SHA-256 hash of source text for staleness detection"
  lifetime: system
  authority: { mode: service, ref: @localization.translation }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: { ref: "Kiva.Translation.source_hash/1", used_for: "published -> stale when source changes" }
}

truth translation_request {
  label: "Tracked request to translate one entity into one target locale"
  lifetime: system
  authority: { mode: service, ref: @localization.translation }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: { schema: "translation_requests", statuses: ["pending", "machine_translated", "needs_review", "completed", "failed"], conflict_target: ["entity_type", "entity_id", "target_locale_code"], ref: "Kiva.Localization.TranslationRequest" }
}

policy lc_resolution_via_resolver on @lc.translation_status {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Public surfaces resolve LC rows through Resolver.resolve_public/2: filter to display-eligible statuses, then walk the fallback chain; draft/rejected/stale are hidden, machine/needs_review are shown but badged unreviewed."
}

policy machine_output_not_approved on @lc.translation_status {
  effect: deny
  status: observed
  confidence: 0.95
  rule: "Machine output is never treated as approved content. On-demand translations insert rows at status 'machine' and are displayed with a 'machine · review pending' badge until a human approves."
}

policy translation_review_staff_only on @lc.translation_status {
  effect: require
  status: observed
  confidence: 0.95
  rule: "approve_translation/reject_translation route through Kiva.Commands (audited single mutation path); actors restricted to staff/admin."
}

flow localization.translation_lifecycle {
  label: "Translation lifecycle (mock translator)"
  status: observed
  confidence: 0.95
  entry: draft
  terminal: published

  state draft
  state machine
  state needs_review
  state approved
  state published
  state stale
  state rejected

  step submit_source {
    actor: @actor.partner
    writes: [@lc.source_locale, @lc.translation_status]
  }

  step machine_translate {
    actor: @actor.ai_agent
    reads: [@lc.source_locale, @locale.fallback_chain]
    writes: [@lc.translation_status, @lc.source_hash, @translation_request]
  }

  step review_translation {
    actor: @actor.staff
    reads: [@lc.translation_status]
    writes: [@lc.translation_status]
  }

  transition draft -> machine on machine_translate do [machine_translate]
  transition machine -> needs_review on mark_for_review
  transition machine -> approved on approve_translation do [review_translation]
  transition needs_review -> approved on approve_translation do [review_translation]
  transition machine -> rejected on reject_translation do [review_translation]
  transition needs_review -> rejected on reject_translation do [review_translation]
  transition approved -> published on publish_translation
  transition published -> stale on source_changed
}

flow localization.on_demand_translation {
  label: "On-demand long-tail translation (FAQ worked example; team posts & encouragement reuse)"
  status: observed
  confidence: 0.9
  entry: fallback_shown
  terminal: machine_row_created

  state fallback_shown
  state translate_requested
  state machine_row_created

  step ensure_translation {
    actor: @actor.visitor
    reads: [@lc.source_locale, @locale.fallback_chain]
    writes: [@lc.translation_status, @translation_request]
  }

  transition fallback_shown -> translate_requested on click_translate
  transition translate_requested -> machine_row_created on ensure_translation do [ensure_translation]
}

flow localization.review_queue {
  label: "Staff translation review queue"
  status: observed
  confidence: 0.95
  entry: queued
  terminal: resolved

  state queued
  state resolved

  step list_queue {
    actor: @actor.staff
    reads: [@lc.translation_status]
  }

  step approve {
    actor: @actor.staff
    writes: [@lc.translation_status]
  }

  step reject {
    actor: @actor.staff
    writes: [@lc.translation_status]
  }

  transition queued -> resolved on approve_translation do [approve]
  transition queued -> resolved on reject_translation do [reject]
}

command approve_translation {
  label: "Approve a machine/needs_review LC row"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["Actor role staff | admin", "LC row in status machine | needs_review"]
  effects: ["Translation marked approved; read model rebuilt", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: { required: ["lc_entity_type", "lc_id"], actors: ["staff", "admin"], handler: "Kiva.Translation.approve/3", verdict_evidence: "The queue row must equip this verdict — source ⇄ target, method, confidence, owning loan (@ask.admin.translation_evidence; audit H4)" }
}

command reject_translation {
  label: "Reject a machine/needs_review LC row"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["Actor role staff | admin", "LC row in status machine | needs_review"]
  effects: ["Translation marked rejected (hidden from public resolution)", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: { required: ["lc_entity_type", "lc_id"], actors: ["staff", "admin"], handler: "Kiva.Translation.reject/2" }
}

command set_locale {
  label: "Set the UI locale (globe dropdown, chat command, LocaleController)"
  servesOutcome: @outcome.actor.native_language_everywhere
  eligibility: ["Any actor including anonymous", "Locale in the supported set (@locale.supported_codes)"]
  effects: ["Session locale set as an explicit choice", "Redirect re-renders in the chosen locale"]
  status: observed
  confidence: 0.9
  metadata: { note: "Registry-backed; previously modeled only via @ai.set_locale_command and the global dropdown's command list — declared 2026-08-10 as the borrower's escape decision (@decision.portal.switch_language). The H2 fix concentrates here: session persistence should follow ONLY this explicit path, with login seeding the session from @user.default_locale (@finding.localization.locale_precedence_defeats_default)." }
}

command create_translation_jobs {
  label: "Fan out translation jobs on loan submission"
  status: asserted
  confidence: 0.8
  metadata: { source: "submit_loan_for_review side_effects (lib/kiva/commands.ex)", note: "Declared as a side effect; no dedicated handler observed wiring it to translation_requests/LC rows." }
}

command publish_translation {
  label: "Publish an approved translation"
  status: asserted
  confidence: 0.8
  metadata: { note: "approved -> published transition exists in the model; no command/handler observed that sets translation_status to 'published' (approve_faq_translation stamps published_at but status stays 'approved')." }
}

view faq_help_page for @localization.on_demand_translation {
  label: "Public Help/FAQ page (localized content with honest fallback)"
  status: observed
  confidence: 0.95
  affordances: [list, expand, translate]
  reveals: [@lc.translation_status, @locale.fallback_chain, @lc.source_locale]
  commands: [translate]
  metadata: { source: "lib/kiva_web/live/faq_live.ex", badges: ["showing <LOCALE> (fallback)", "machine · review pending", "approved/published/source"], entry: "Kiva.Content.ensure_faq_translation/3" }
}

view translation_review_queue for @story.staff.decision_sweep {
  label: "Staff translation review queue"
  status: observed
  confidence: 0.95
  affordances: [list, approve, reject]
  reveals: [@lc.translation_status, @lc.source_locale]
  commands: [approve_translation, reject_translation]
  metadata: { source: "lib/kiva_web/live/admin_live.ex", queue: "Kiva.Translation.list_review_queue/0 across loan, faq_entry, team_post, encouragement_message LC rows in status machine|needs_review" }
}

# --- 2026-08-10: audit finding H2 — locale precedence defeats the pillar --

evidence evidence.localization.locale_precedence_audit {
  kind: observation
  occurredAt: "2026-08-10"
  subject: @localization.core
  method: "Dashboard first-person audit: code read of lib/kiva_web/plugs/set_locale.ex:14-24 plus a rendered cold-read logged in as the es-default borrower persona"
  observation: "Locale precedence is params > session > user default, and the resolved value is written back to the session on EVERY request — an anonymous visit's en fallback becomes a sticky session choice that permanently shadows the account's default_locale_code. Observed: the es-default borrower receives an English portal titled 'Here are your loans in your language.'"
  provenance: { doc: "docs/storytime/dashboard_first_person_audit_2026-08-10.md finding H2" }
  scope: ["set_locale plug behavior at first login as of 2026-08-10"]
  status: observed
  confidence: 0.95
}

finding finding.localization.locale_precedence_defeats_default {
  claim: "The native-language promise breaks at first login: session write-back of the resolved locale shadows the account's default_locale_code, so a first-time borrower whose default is es gets a sticky en experience."
  basedOn: [@evidence.localization.locale_precedence_audit]
  scope: ["Logged-in surfaces reached from a prior anonymous session"]
  supports: []
  contradicts: ["@outcome.actor.native_language_everywhere holding at first login"]
  limitations: ["Fix shape sketched, not decided: persist session locale only on explicit choice (@set_locale) and/or seed session locale from @user.default_locale at login (audit H2)"]
  invalidatedBy: ["The precedence fix lands with the locale-at-login regression test (login as an es-default user from an en session -> es page)"]
  strength: supported
  status: observed
  confidence: 0.95
}

question question.localization.bulk_translation_approval on @translation_review_queue {
  questionType: open_question
  ask: "Does a bulk 'approve machine translations above confidence threshold' command get registered (preview -> confirm through the registry), or does translation review stay strictly per-row?"
  whyItMatters: "105 flat rows with per-row ceremony is the current wall (audit H4/M5); the audit's rethink sketches bulk-approve-above-threshold, but no owner ruling exists — the staff screenplay deliberately does not voice it as available."
  owner: "Paul Ericksen"
  neededBy: "The admin queues-first rework"
  blocking: ["The translation queue's bulk action row"]
  resolveWith: ["Product ruling; if yes — a registered command with threshold eligibility and preview -> confirm"]
  knowledge: {
    scope: ["Staff translation review queue"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-08-10"
    invalidatedBy: ["The ruling lands either way"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}

# --- Durable knowledge (2026-07-26 grammar adoption) -------------------

evidence evidence.localization.fuzzy_autofill_examples {
  kind: observation
  occurredAt: "2026-07-07"
  subject: @lc.translation_status
  method: "Manual catalog review during the portfolio-redesign session; each pair verified in priv/gettext/*/LC_MESSAGES/default.po before repair"
  value: { examples: ["Key -> Kenia (es)", "Your loans -> ¡Tu préstamo ya está activo! 🎉 (es)", "Remaining -> Pagando (es)", "Your client secret -> Prestaste (es)", "Welcome back, %{name} -> Bienvenido de nuevo (es, drops name)"] }
  provenance: { commit: "60e21c8", session: "claude-code 2026-07-07 portfolio redesign" }
  integrity: { verification: "Pairs reproduced from the pre-repair catalog state in the commit diff" }
  scope: ["priv/gettext {es,de,fr,nl} default.po as of 2026-07-07 pre-repair"]
  status: observed
  confidence: 1.0
}

evidence evidence.localization.catalog_repair_runs {
  kind: observation
  occurredAt: "2026-07-07"
  subject: @localization.core
  method: "awk/grep audit over all four default.po files counting empty msgstr and fuzzy flags, run after each scripted fill pass"
  value: { pass_a: "42 entries filled per locale; audit empties=0 fuzzy=0 x4", pass_b: "73 entries filled per locale (cumulative incl. slice-and-dice strings); audit empties=0 fuzzy=0 x4", spot_check: "Rendered /portfolio in es verified end-to-end" }
  provenance: { commit: "60e21c8", note: "Fill script was session scratch (fill_po.py) and was not retained; audits and rendered screenshots recorded in the session transcript" }
  integrity: { verification: "Post-repair catalog state is the committed state of 60e21c8" }
  scope: ["priv/gettext {es,de,fr,nl} default.po at commit 60e21c8"]
  status: observed
  confidence: 0.95
}

incident incident.localization.fuzzy_autofill_mistranslations {
  incidentState: resolved
  severity: medium
  occurredAt: "2026-07-07"
  detectedAt: "2026-07-07"
  affectedScope: ["es/de/fr/nl default.po catalogs", "Rendered surfaces: loan drawer, developer portal, portfolio greeting"]
  impact: ["~10 user-visible strings per locale rendered semantically wrong translations (not merely untranslated)"]
  detection: ["Manual catalog audit while translating new portfolio strings; no automated fuzzy check existed"]
  timeline: [{ at: "2026-07-07", event: "Wrong fuzzy autofills found, repaired via scripted fill, all catalogs audited to zero-empty/zero-fuzzy, committed in 60e21c8" }]
  containment: ["Same-session repair of every empty and fuzzy entry across all four locales"]
  recovery: ["Scripted msgstr fill + fuzzy-flag clearing, then zero-empty/zero-fuzzy audit (formalized as @recipe.localization.catalog_repair)"]
  rootCauses: ["gettext merge fuzzy-matching fills msgstr with nearest-neighbor translations, and Elixir Gettext compiles fuzzy entries into served output"]
  contributingFactors: ["No post-merge fuzzy/empty audit step in the workflow", "Catalog entries are rarely re-read once written"]
  obligations: ["Run @recipe.localization.catalog_repair after every gettext extract+merge", "Keep all four catalogs at zero empty and zero fuzzy entries"]
  knowledge: {
    scope: ["kredo gettext default-domain catalogs es/de/fr/nl"]
    evidence: [@evidence.localization.fuzzy_autofill_examples]
    owner: "Paul Ericksen"
    learnedAt: "2026-07-07"
    invalidatedBy: ["Gettext toolchain change that stops compiling fuzzy entries", "Catalog workflow moves off gettext"]
    supersedes: []
  }
  status: confirmed
  confidence: 0.98
}

heuristic heuristic.localization.zero_fuzzy_after_merge {
  version: "1.0.0"
  maturity: active
  semantic: {
    statement: "Treat every fuzzy msgstr as wrong until reviewed: after any gettext extract+merge, review and clear all fuzzy flags and fill all empty msgstrs before shipping."
    appliesWhen: ["mix gettext.extract --merge touched any PO file", "New user-facing strings were added"]
    avoidWhen: ["A locale is intentionally unsupported (none today)"]
    rationale: ["Fuzzy autofills are nearest-neighbor guesses that compile into served output and read as confidently wrong text"]
    examples: ["The 2026-07-07 repair pass"]
    counterexamples: []
    confidenceBoundary: ["Guidance for the maintenance workflow; @recipe.localization.catalog_repair owns the executable method and its verification"]
    verification: ["for loc in es de fr nl: grep -c ', fuzzy' and an awk scan for empty msgstr over priv/gettext/$loc/LC_MESSAGES/default.po must both report zero"]
    promotionCriteria: ["Promote to a pattern only if a CI gate makes zero-fuzzy a normative promise"]
  }
  knowledge: {
    scope: ["kredo gettext catalogs"]
    evidence: [@evidence.localization.fuzzy_autofill_examples, @evidence.localization.catalog_repair_runs]
    owner: "Paul Ericksen"
    learnedAt: "2026-07-07"
    invalidatedBy: ["Gettext toolchain stops compiling fuzzy entries"]
    supersedes: []
  }
  status: observed
  confidence: 0.9
}

pattern pattern.localization.sidecar_public_resolution {
  category: aspect
  version: "1.0.0"
  summary: "Public reads of translatable entity content resolve through the sidecar resolver with honest fallback"
  rationale: "Direct LC-row selection recreates the fallback/badging bug class one surface at a time"
  parameters: {
    fallback_chain: "requested -> en"
    display_eligible: ["source", "published", "approved", "machine", "needs_review"]
  }
  clauses: [
    "Every public or lender-facing read of *_lc entity text resolves through Kiva.Localization.Resolver.resolve_public/2 or a context function wrapping it",
    "Resolution filters to display-eligible translation statuses, then walks the fallback chain requested -> en",
    "A fallback-locale or unreviewed-machine resolution is visibly badged; silent substitution is forbidden",
    "A missing row degrades to a stable identifier (slug or public_id), never to a crash or empty string"
  ]
  verification: [
    "Render the surface in a non-source locale with an approved translation present",
    "Render with only a machine translation and assert the unreviewed badge",
    "Render with no target-locale row and assert the fallback badge plus identifier degradation"
  ]
  status: observed
  confidence: 0.9
}

adoption adoption.localization.public_surfaces_resolution {
  pattern: @pattern.localization.sidecar_public_resolution
  patternVersion: "1.0.0"
  patternFingerprint: "sha256:7ac6e082da62014b3b46bac629551687a4b4ade575bed1558e447ec6ee97dafe"
  scope: class
  targets: [@faq_help_page, @translation_review_queue]
  qualification: "Every render of *_lc-backed entity text (loans, borrowers, partners, sectors, FAQ entries, team posts, encouragement messages) on a public or lender surface"
  coverageVerifier: "tools/lssd/localization_resolution_coverage.sh"
  bindings: { fallback_chain: "requested -> en" }
  implementation: ["lib/kiva/localization/resolver.ex", "lib/kiva/lending.ex", "lib/kiva/portfolio.ex", "lib/kiva/taxonomy.ex", "lib/kiva/content.ex", "lib/kiva_web/components/app_components.ex"]
  verifiedBy: ["test/kiva_web/live/faq_live_test.exs", "test/kiva_web/live/loan_live_test.exs", "test/kiva_web/live/portfolio_live_test.exs"]
  conformance: provisional
  exceptions: [
    "PortfolioLive loan rows resolve titles/borrowers via resolve_public but do not yet surface the fallback badge; owner Paul Ericksen, review on the next portfolio change",
    "The Kiva-compat machine surface (kiva_v1 *_json, kiva_graphql loan_shape/resolvers) deliberately resolves via Kiva.KivaCompat.Mapping to mirror legacy Kiva language semantics instead of the product badge+fallback contract; whether Mapping filters display-eligible statuses is reviewable on next compat change",
    "Staff surfaces (admin_live review detail, translation.ex queue) read raw LC rows by design per policy translation_review_staff_only"
  ]
  status: observed
  confidence: 0.85
}

outcome outcome.localization.complete_catalogs {
  label: "All four locale catalogs fully translated"
  status: observed
  confidence: 0.95
  metadata: { definition: "priv/gettext {es,de,fr,nl} default.po each report zero empty msgstr and zero fuzzy entries, and new user-facing strings ship translated" }
}

recipe recipe.localization.catalog_repair for @outcome.localization.complete_catalogs {
  label: "Gettext catalog repair after extract+merge"
  version: "1.0.0"
  maturity: qualified
  semantic: {
    suitableWhen: ["After mix gettext.extract --merge", "After adding user-facing strings", "When an audit finds empty or fuzzy entries"]
    contraindications: ["Catalogs not managed by gettext"]
    requires: [@localization.core]
    inputs: ["New/changed msgids", "Human-authored translation table for es/de/fr/nl"]
    parameters: {
      locales: { required: ["es", "de", "fr", "nl"], freeze: run_start }
      domain: { required: "default", freeze: run_start }
    }
    steps: [
      { id: extract, invokes: "mix gettext.extract --merge", produces: "merged POT + PO files" },
      { id: audit, invokes: "awk/grep scan per locale", produces: "list of empty and fuzzy entries" },
      { id: fill, invokes: "scripted msgstr fill from the translation table, clearing fuzzy flags on every touched entry", produces: "repaired PO files" },
      { id: verify, invokes: "repeat the audit expecting empties=0 fuzzy=0 for every locale", produces: "zero-defect audit" },
      { id: spot_render, invokes: "render one changed surface in a non-en locale", produces: "visual confirmation" }
    ]
    produces: ["Catalogs with zero empty and zero fuzzy entries in all four locales"]
    invariants: ["No fuzzy flag survives on a filled entry", "API-syntax msgids (enum hints, scope names) stay literal in every locale", "Existing translations are only overwritten deliberately (wrong autofills), never blindly"]
    limitations: ["Guarantees coverage, not fluency — translation quality is only as good as the supplied table", "Native-speaker review is not part of the technical gate"]
    qualification: {
      technical: ["Audit reports empties=0 and fuzzy=0 for es, de, fr and nl"]
      human: ["A rendered non-en surface is spot-checked; fluency review by a speaker remains open per run"]
      reproducibility: "Two production runs on 2026-07-07 passed all technical gates"
    }
    verification: ["Per-locale audit counts", "Rendered locale spot check", "mix test green (catalog syntax compiles)"]
    humanGates: ["fluency_review"]
  }
  qualifiedBy: [@run.localization.catalog_repair_20260707a, @run.localization.catalog_repair_20260707b, @run.localization.catalog_repair_20260728]
  status: observed
  confidence: 0.9
}

recipe_run run.localization.catalog_repair_20260707a of @recipe.localization.catalog_repair {
  recipeVersion: "1.0.0"
  recipeFingerprint: "sha256:02c5e4e38321d7847e6059c7a7e136f2ba327d53311fc85f0dd35f0120ad99c6"
  purpose: production
  jobs: ["session-2026-07-07-fill-pass-a"]
  occurredAt: "2026-07-07"
  inputs: [{ role: translation_table, note: "42 entries per locale: portfolio-redesign strings plus repair of ~10 wrong fuzzy autofills and older gaps" }]
  resolvedParameters: { locales: ["es", "de", "fr", "nl"], domain: "default" }
  environment: { repo: "kredo", toolchain: "mix gettext + python3 fill script (session scratch)" }
  outputs: [{ artifact: "priv/gettext/*/LC_MESSAGES/default.po", commit: "60e21c8" }]
  verdicts: {
    execution: passed
    zero_empty_audit: passed
    zero_fuzzy_audit: passed
    rendered_spot_check: passed
    fluency_review: mixed
  }
  supports: ["The scripted fill + audit loop drives four catalogs to zero-defect in one pass"]
  contradicts: []
  operatorDecision: "Agent-authored translations shipped for the demo; native-speaker fluency review not performed"
  status: observed
  confidence: 0.95
}

recipe_run run.localization.catalog_repair_20260707b of @recipe.localization.catalog_repair {
  recipeVersion: "1.0.0"
  recipeFingerprint: "sha256:02c5e4e38321d7847e6059c7a7e136f2ba327d53311fc85f0dd35f0120ad99c6"
  purpose: production
  jobs: ["session-2026-07-07-fill-pass-b"]
  occurredAt: "2026-07-07"
  inputs: [{ role: translation_table, note: "73 cumulative entries per locale: slice-and-dice + repayment-chart strings, chart-subtitle rewrite, and the repayments/reembolsos term fix" }]
  resolvedParameters: { locales: ["es", "de", "fr", "nl"], domain: "default" }
  environment: { repo: "kredo", toolchain: "mix gettext + python3 fill script (session scratch)" }
  outputs: [{ artifact: "priv/gettext/*/LC_MESSAGES/default.po", commit: "60e21c8" }]
  verdicts: {
    execution: passed
    zero_empty_audit: passed
    zero_fuzzy_audit: passed
    rendered_spot_check: passed
    fluency_review: mixed
  }
  supports: ["The recipe holds under a second, larger same-day pass including plural forms"]
  contradicts: []
  operatorDecision: "Same as run a: shipped for the demo; fluency review remains an open human gate"
  status: observed
  confidence: 0.95
}

recipe_run run.localization.catalog_repair_20260728 of @recipe.localization.catalog_repair {
  recipeVersion: "1.0.0"
  recipeFingerprint: "sha256:02c5e4e38321d7847e6059c7a7e136f2ba327d53311fc85f0dd35f0120ad99c6"
  purpose: production
  jobs: ["session-2026-07-28-fill-provenance"]
  occurredAt: "2026-07-28"
  inputs: [{ role: translation_table, note: "44 entries per locale: provenance timeline UI strings plus the partner-repayments strings and 10 fuzzy repairs from the same merge" }]
  resolvedParameters: { locales: ["es", "de", "fr", "nl"], domain: "default" }
  environment: { repo: "kredo", toolchain: "mix gettext + python3 fill script (session scratch, re-derived from the recipe steps)" }
  outputs: [{ artifact: "priv/gettext/*/LC_MESSAGES/default.po", note: "committed with the provenance feature" }]
  verdicts: {
    execution: passed
    zero_empty_audit: passed
    zero_fuzzy_audit: passed
    rendered_spot_check: passed
    fluency_review: mixed
  }
  supports: ["Third production pass; the recipe survives being re-derived from its own steps after the original script was lost with session scratch"]
  contradicts: []
  operatorDecision: "Agent-translated; native-speaker fluency review remains the open human gate"
  status: observed
  confidence: 0.95
}
```
