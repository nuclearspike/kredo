# FractalFlow Grammar Upgrade + First-Person Layer — Campaign Report

**Date:** 2026-08-10 · **Scope:** every ACTIVE contract in `docs/fractalflow/`
(9 upgraded, 1 created) · **Authorities applied:**
`~/projects/LSSD/EXISTING_PROJECT_UPGRADE_GUIDE.md` (through v1.12),
`FractalFlow-spec.lssd.md`, StoryTime doc 7 §17.2/§17.8 (Laws 22–24), doc 9
§9/§11. · **Seed:** `docs/storytime/dashboard_first_person_audit_2026-08-10.md`.
**Doc-layer only — no code touched.** Working tree left uncommitted for review.

## Checker outcomes

| Check | Before | After |
|---|---|---|
| localcode `Lssd check` (docs/fractalflow) | clean | **clean** |
| `lssd_growth.py report --all-lssd` | 292 nodes / 304 edges / **69 dangling refs** | 381 nodes / 588 edges / **0 dangling refs**, 0 parse errors |
| Journey layer | 0 stories, 0 stages, 0 decisions, 1 outcome | 4 stories, 9 stages, 17 decisions, 8 asks, 5 intents, 15 outcomes, 1 convergence_point, 4 initiatives |

The 69 dangling refs were almost all `do [@step.x]` action lists in flows
(steps are not referenceable nodes; the spec's own examples use bare action
identifiers) — sigils stripped, meaning unchanged. The last four were refs
swallowing a trailing sentence period; reworded.

## Per-contract summary

**kiva_future_demo_product (0.2.0 → 0.3.0)**
- `Canonical-For`/`Status: ACTIVE` header; model block gains status/confidence
  (all ten files got both — not repeated below).
- System/module `contains` wiring; two missing product modules added
  (`module.messaging_reveal`, `module.identity_access`).
- Product-pillar outcomes: `outcome.actor.native_language_everywhere`,
  `outcome.actor.ask_and_act_in_place`, plus `outcome.staff.decisions_cleared`;
  every capability now serves an outcome (one exception below).
- The audit artifact declared (`@dashboard_first_person_audit`).
- **Staff first-person layer** (the one dashboard no subsystem owns):
  embodied `actor.staff` with drafted lexicon, `story.staff.decision_sweep`,
  stages `queue_scan` + `unequipped_verdict` (H4 failure path), four decisions
  resolving cross-file into the real verdict commands, asks
  `admin.decision_queue` / `admin.translation_evidence`, intent
  `whats_waiting`, new asserted truth `admin.queue_aging`, and
  `convergence_point cp.admin.morning_decisions` (status **candidate** — not
  practitioner-recognized). Audit's verbatim header transcription target
  preserved on the stage.
- The four Q1–Q4 decision_records **moved to their owning subsystems** (ids
  unchanged; pointer comment left in place); each now `mandates` an initiative.
- **Initiative ledger** (v1.9): `product.sender_reveal`,
  `product.bulk_collections`, `product.risk_details_page`,
  `product.restore_chat` — all `committed`, originKind `decision_mandate`,
  DoD spelled out. The rulings' implementation state lives here, not on the
  records.
- `decision.rebrand_kredo` restructured into full decision_record grammar
  (content unchanged; the `@`-email strings that parsed as refs reworded).
- `question.docs.developer_subsystem_contract` **resolved** (skeleton
  authored; see below).

**loan_lifecycle (0.3.0 → 0.4.0)** — home of the lender + partner journeys
- Embodied `actor.lender` (Morgan) and `actor.partner` (Ana) with drafted
  lexicons (rows carry banned terms + homonym warnings; `verbatim_sentences`
  deliberately empty — no practitioner has narrated).
- Outcomes: `lender.returns_relent` (steps_max 2), `partner.day_collected`
  (steps_max 2), `partner.loan_listed` (steps_max 3).
- `story.lender.portfolio_return` (stages `arrival` + `risk_opaque` bail) and
  `story.partner.morning_operations` (stages `morning_checkin` +
  `bounced_wall` failure), each with interior monologue, ranked question stack
  (audit-seeded, answering truths named per entry), screenplay stub
  (§17.8 shape, `forces_truths` per beat), and
  `practitionerGate: practitioner_unvalidated` / `evidenceLevel: agent_walked`.
- **Truths filed backward:** `loan.fundraising_ends_at` (asserted — audit saw
  it in schema, no surface), `repayment_schedule.item_terms` (observed — the
  in-contract schedule evidence already exercises due_on/amounts),
  `loan.loss_attribution` + `repayment.arrears_aging` (asserted — forced by
  the risk-details ruling and both stacks), `recognized_by` on
  `loan.story_text` (H3: name/title/photo/date/amount, never a raw id).
- `constraint.portfolio.usd_only_no_fx` + `question.portfolio.fx_modeling`
  (FX loss is out of model; the ruling's "modeled truth or explicit exclusion"
  is the owner's open call).
- decision_records `partner_bulk_collections` + `lender_risk_details_page`
  (moved here, full grammar, rulings preserved).
- Commands on the touched journeys lifted to full grammar
  (servesOutcome/eligibility/effects from their own metadata); dashboard views
  repointed from flows/capabilities to the new stories (Law 14).
- `ask.partner.due_today`, `ask.partner.expiring_campaigns`,
  `ask.portfolio.find_loan`, `ask.portfolio.risk_breakdown`; intents
  `portfolio.relend_returns` (implemented — the assistant already does it),
  `portfolio.risk_question`, `partner.collect_today`;
  `question.partner.expiring_rescue` (no rescue command exists — not invented).

**messaging_reveal (0.1.0 → 0.2.0)** — home of the borrower journey
- Embodied `borrower` (Rosa, es) with drafted es lexicon (incl. the L3 rule:
  never a bare locale code — actor phrasing instead).
- Outcomes `borrower.money_status_known` (steps_max 1) and
  `borrower.encouraged` (steps_max 2); module/system `contains` wiring;
  capabilities serve outcomes.
- `story.borrower.portal_checkin` with stages `opening` (audit's four-entry
  stack + the verbatim es transcription target, state-dependency noted),
  `wrong_language` (H2 failure path), `loan_closed` (the missing closure
  moment); screenplay stub with `forces_truths` = `fundraising_ends_at`,
  `user.profile_public`, `item_terms`; decisions incl. `post_update` (resolves
  the orphaned `post_borrower_update`) and `switch_language` (→ `set_locale`).
- decision_record `encouragement_sender_reveal` (moved here, full grammar).
- `question.portal.borrower_update_authoring` — the command is
  partner/staff-only today; who authors is the owner's call.
- Staff-verdict commands (`approve_message`/`reject_message`) and
  `post_borrower_update` lifted to full grammar.

**ai_dialogue (0.2.0 → 0.3.0)**
- Doc-fidelity: stale `ChatComponent` mentions updated to `ChatLive`
  (the product contract already recorded the 044f9b2 rename as observed).
- Honesty note on `floating_chat_widget`: the component works but its
  `live_render` is commented out — unreachable everywhere (audit H1).
- decision_record `restore_chat_launcher` (moved here, full grammar,
  mandates `product.restore_chat`); `ai.respond` serves the chat pillar
  outcome. The `@registry` token in a label that parsed as a ref reworded.

**localization (0.3.0 → 0.4.0)**
- **H2 captured as typed knowledge:** `evidence.localization.locale_precedence_audit`
  + `finding.localization.locale_precedence_defeats_default` (session
  write-back shadows `default_locale_code`; fix shape recorded in
  limitations, invalidated by the locale-at-login regression test).
- `command set_locale` declared (registry-backed; previously only implied by
  three other nodes) — the H2 fix concentrates on it.
- `approve_translation`/`reject_translation` lifted; queue view repointed to
  the staff story; `question.localization.bulk_translation_approval`
  (bulk approve-above-threshold is sketched in the audit but **unruled** —
  the staff screenplay deliberately does not voice it).

**identity_access (0.1.0 → 0.2.0)**
- `truth user.profile_public` filed backward (asserted; forced by the
  sender-reveal ruling; default private).
- `outcome.actor.signed_in` (login view now outcome-derived) with an owned
  dormancy question (`question.identity.login_journey_growth`) instead of a
  faked story.

**lending_teams (0.2.0 → 0.3.0)** — `outcome.lender.lend_together`; commands
lifted/wired; duplicate `complete_demo_lend` declaration points at the
canonical loan_lifecycle declaration.

**permissions_trust (0.2.0 → 0.3.0)** — outcomes
`admin.privilege_outliers_visible` + `lender.trust_verified`; outlier view
repointed to the staff story, trust panel to its outcome; `revoke_permission`
and the status/verdict commands lifted.

**provenance (0.1.0 → 0.2.0)** — `outcome.staff.authenticity_traced`; timeline
view repointed to it.

**developer_compat (NEW, 0.1.0, skeleton)** — resolves the product's open
question. Module, embodiment-stub actor, `outcome.developer.integrated`
(steps_max 3), three asserted truths (oauth_client, api_key,
capability_manifest), manifest-generated-not-authored policy, and the
qualification-bounded-claims policy referencing the existing compat
qualification. Depth is **deliberately dormant** behind
`question.developer.journey_growth` — no fresh code read was taken, so no
journey was faked.

## Practitioner Reality Gate honesty (v1.6/v1.12)

Nothing in this campaign is practitioner-validated. All four journeys carry
`practitionerGate: practitioner_unvalidated` and `evidenceLevel: agent_walked`
(the audit's rendered cold-reads). All lexicons and monologues carry explicit
drafted-not-harvested provenance with empty `verbatim_sentences`. The next
practitioner-gate session should harvest verbatims per locale (es first —
Rosa and Ana) and correct the stacks by recognition. The convergence point is
`candidate`, not `recognized`.

## Open questions needing the owner

1. `question.portfolio.fx_modeling` — model FX loss or ship the risk page
   with an explicit all-USD exclusion note (blocks one line of Q3's page).
2. `question.portal.borrower_update_authoring` — does Rosa author updates
   directly, or request via her partner? (`post_borrower_update` is
   partner/staff-only and surfaceless today.)
3. `question.partner.expiring_rescue` — what can Ana legally DO about an
   expiring underfunded campaign? No command exists; none invented.
4. `question.localization.bulk_translation_approval` — register a bulk
   approve-machine-above-threshold command, or keep review per-row?
5. `question.provenance.non_admin_visibility` (pre-existing, unchanged).
6. **Actor identity duplication:** the same actor is redeclared per contract
   (three `actor.lender`s, two bare `lender`s, etc.). The growth checker
   binds each journey to one declaration, so sibling declarations still
   render curled. Consolidating to one declaration per actor (others
   referencing it) is a mechanical follow-up needing a naming ruling —
   NOT done here because it would rewrite ids the task said to preserve.
7. **Layout:** contracts live centrally in `docs/fractalflow/` rather than
   per-subtree `FractalFlow.lssd.md` files (the spec's Placement section
   prefers per-subtree; the upgrade guide is silent). Kept central by design —
   `Canonical-For` headers added so the path mapping is explicit, and the
   localcode checker is **clean on the docs/fractalflow scope**. One concrete
   wrinkle found: a repo-root-scoped `Lssd check` reports "MISSING: no active
   FractalFlow.lssd.md covers ." — the checker keys on the filename, not the
   `Canonical-For: .` header the product contract now carries. A ~15-line root
   `FractalFlow.lssd.md` pointer contract (delegating to `docs/fractalflow/`)
   would silence it without moving anything; deliberately NOT added — the
   owner reserved layout, so this is his call: pointer file, per-subtree
   restructure, or live with root-scope checks reporting missing.

## Deliberately not upgraded (and why)

- **Non-dashboard actors** (trustee, moderator, translator, visitor,
  provenance cast, AI-surface actors) remain story-less/curled — the v1.7/v1.12
  guides both mandate touched-frontier growth, and hollow stories are
  non-conforming. They grow when their surfaces are next touched.
- **Declared-not-built commands** (`manage_permission_group`, `manage_locale`,
  `reset_demo_seed_state`, `create_translation_jobs`, `publish_translation`)
  keep their asserted, undeveloped shape — giving them eligibility/effects
  would overstate reality.
- `ai.command_registry` / `ai.graphql_surface` systems have no capability
  children to contain in their file; left curled rather than adding hollow
  nodes. `capability.scale_generator` records the outcome it *preserves* in
  prose (internal tool; no served actor outcome to claim).
- Untouched views (loan browse/profile, FAQ, teams, basket, notifications,
  audit timeline, analytics) keep their flow/capability `for`-targets; only
  the four audited dashboards' views were repointed to journeys. Migrating
  the rest is touched-story work.
- Existing prose that was already grammar-valid was left byte-identical
  wherever possible (diff-reviewability rule).

## Follow-through order (from the audit, unchanged)

H1 (`product.restore_chat`) + H2 (locale precedence fix per the finding) are
prerequisites; then per-dashboard reworks, each consuming its stage record +
screenplay from the owning contract; pattern extraction
(`answer-first-hero`, `folded-region-header`, `evidence-bearing-queue-row`)
only once two surfaces share the shape.
