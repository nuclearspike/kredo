<!--
Canonical-For: lib/kiva/provenance.ex, lib/kiva/provenance
Status: ACTIVE
-->

# FractalFlow — Listing Provenance Subsystem

Models the auditor-facing authenticity layer: an append-only trail of who
produced, transformed, reviewed, and re-scoped every artifact behind a loan
listing — photos (capture device/app/GPS), consent, identity checks, site
visits, story authorship and AI rewording (which model, when), translation
method (machine/template/human, by whom, where), and visibility changes.
The DEMO fabricates the historical trail in seeds; the structure, chains, and
live review events are real. Who may see provenance beyond staff/admin is a
deliberately open product decision — the data model carries a per-event
audience so that policy stays data-driven.

2026-08-10: grammar upgrade (header, model status, auditor outcome).

```lssd
model kiva.provenance@0.2.0 {
  namespace: "kiva.provenance"
  revision: "2026-08-10"
  status: observed
  confidence: 0.9
}

outcome outcome.staff.authenticity_traced {
  label: "An auditor reconstructs who produced every artifact behind a listing — capture to approval — from one timeline"
  steps_max: 1
  vocabulary: actor
  summary: "One step from the loan profile to the full grouped trail (photos, consent, identity, story + AI rewording, translation method, listing decisions) with verifying hash chains. Wider-than-staff visibility stays an open product decision (@question.provenance.non_admin_visibility)."
  status: asserted
  confidence: 0.85
}

module provenance.core {
  label: "Listing provenance (append-only authenticity trail)"
  status: observed
  confidence: 0.95
  metadata: { source: "lib/kiva/provenance.ex", fabricator: "lib/kiva/provenance/fabricator.ex", table: "provenance_events", note: "Fabricated demo history materializes lazily on first staff view; live events ride existing commands." }
}

actor actor.field_officer {
  label: "Partner field officer (captures photos, consent, site visits)"
  status: observed
  confidence: 0.9
  metadata: { note: "Demo: fabricated named personas per partner; no user accounts." }
}

actor actor.partner_staff {
  label: "Partner staff (authors stories, verifies identity, submits listings)"
  status: observed
  confidence: 0.9
}

actor actor.staff_auditor {
  label: "Kredo staff/admin (reviews, approves, audits the full trail)"
  status: observed
  confidence: 0.95
}

actor actor.ai_model {
  label: "AI models (story rewording, machine translation) — named + versioned per event"
  status: observed
  confidence: 0.95
}

actor actor.human_translator {
  label: "Human translator (named, qualified, located per event)"
  status: observed
  confidence: 0.9
}

# --- Truths -----------------------------------------------------------
truth provenance.event {
  label: "One append-only provenance event on a listing artifact"
  lifetime: system
  authority: { mode: service, ref: @provenance.core }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "provenance_events",
    fields: "loan_id, subject_type (photo|consent|identity|site_visit|story|translation|listing), subject_ref, event_type, occurred_at, actor_kind (human|ai|system), actor_name, actor_role, actor_user_id, tool (map: app/version/device or provider/model or template), location (map: lat/lng/place), source_locale, target_locale, source_hash, content_hash, visibility, details (map)",
    note: "No updated_at column — the row is immutable by construction."
  }
}

truth provenance.event_taxonomy {
  label: "Event type taxonomy"
  lifetime: system
  authority: { mode: service, ref: @provenance.core }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: { types: ["photo.captured", "photo.uploaded", "photo.reviewed", "photo.approved", "photo.visibility_changed", "consent.recorded", "identity.verified", "site.visited", "story.authored", "story.ai_reworded", "story.reviewed", "story.approved", "translation.machine", "translation.template", "translation.human", "translation.reviewed", "translation.approved", "translation.rejected", "listing.submitted", "listing.approved"] }
}

truth provenance.content_chain {
  label: "Derivation chain: an event's source_hash links to an earlier event's content_hash"
  lifetime: system
  authority: { mode: service, ref: @provenance.core }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: { verify: "Kiva.Provenance.chain_status/1 — linked | broken per derived event; hashes are sha256 of the actual seeded content so the chain genuinely verifies", note: "Linkage is loan-global by design (derivations legitimately cross subjects: translations and listing decisions derive from the story). Non-text artifacts use domain-prefixed hashes (photo:, consent:) so unrelated artifacts cannot collide accidentally." }
}

truth provenance.event_audience {
  label: "Per-event audience (admin | partner | lender | public) — data now, policy later"
  lifetime: system
  authority: { mode: human, ref: @actor.staff_auditor }
  visibility: [staff, system]
  status: observed
  confidence: 0.9
  metadata: { default: "admin", note: "Only the staff/admin surface renders provenance today; the field exists so opening visibility later is a policy change, not a migration." }
}

provenance_record provenance.listing_lineage {
  label: "The lineage a listing carries — sources, hands, transformations, custody, integrity"
  subject: @provenance.content_chain
  sources: ["borrower photograph (subject_ref photo:<image_url>)", "borrower consent record", "identity check", "field site visit", "the borrower's story as first authored", "loans_lc rows — the real localized content, not a stand-in"]
  activities: ["photo.captured → uploaded → reviewed → approved → visibility_changed", "consent.recorded", "identity.verified", "site.visited", "story.authored → ai_reworded → reviewed → approved", "translation.machine|template|human → reviewed → approved|rejected", "listing.submitted → approved"]
  agents: ["@actor.field_officer", "@actor.partner_staff", "@actor.staff_auditor", "@actor.ai_model", "@actor.human_translator", "the system itself — actor_kind is one of human|ai|system on every row"]
  transformations: ["rewording of an authored story by a model", "machine, template, or human translation from source_locale to target_locale", "review and approval decisions that change visibility"]
  chainOfCustody: ["Each derived event names the content_hash of the event it came from in its own source_hash", "Kiva.Provenance.chain_status/1 walks the loan's events in order and marks each one origin (no source_hash), linked (source_hash already seen), or broken (source_hash never produced)", "Linkage is loan-global on purpose: a translation and a listing decision both derive from the story, so custody legitimately crosses subject types"]
  integrity: { sha256: "lowercase hex sha256 of the actual content, via Kiva.Provenance.sha/1", verification: "Non-text artifacts are hashed under a domain prefix (photo:<url>, consent:<public_id>) so a photo and a paragraph cannot collide. Rows are immutable by construction — no updated_at column, and the provenance_events_guard trigger raises on UPDATE and on DELETE of any row not marked details.fabricated=true." }
  capturedAt: "per event: occurred_at, backdated by the fabricator for pre-runtime history and set at command time for live events"
  limitations: ["Most history is fabricated: deterministic per loan, structurally faithful, and hash-verifiable, but the people, devices, GPS fixes, and places in a seeded row are invented — @demo_fabrication_disclosure", "Only events born inside a command (submit_loan_for_review, approve_loan_listing, approve_translation, reject_translation) describe something that actually happened", "Provenance writes are best-effort: a failure logs and lets its command succeed, so absence of an event is not proof the activity did not occur", "chain_status reports broken for an event whose source_hash was never produced, which is indistinguishable from an event whose predecessor was simply never recorded"]
  status: observed
  confidence: 0.95
}

# --- Policies ---------------------------------------------------------
policy append_only on @provenance.event {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Provenance rows are never updated, and live rows are never deleted — enforced at the database by the provenance_events_guard trigger (updates always raise; deletes raise unless the row carries details.fabricated=true, i.e. a re-derivable demo fixture). There is no mutation command. A correction is a new event referencing the corrected one in details.correction_of."
}

policy admin_full_visibility on @provenance.event {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "Staff/admin see every event for every listing regardless of the event's audience field (LoanLive.Show renders the timeline only for role in staff|admin)."
}

policy live_events_ride_commands on @provenance.event {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Runtime provenance writes happen inside existing command side effects — submit_loan_for_review (story.authored + listing.submitted + translation.machine fan-out), approve_loan_listing, approve_translation, reject_translation — never via a direct provenance mutation path. Live events carry the same hash grammar as fabricated ones so chains verify on live-born loans. Writes are best-effort: a provenance failure (changeset error or raise) logs and never fails the owning command."
}

policy demo_fabrication_disclosure on @provenance.event {
  effect: require
  status: observed
  confidence: 0.95
  rule: "All pre-runtime history is fabricated deterministically per loan by Kiva.Provenance.Fabricator — lazily on first staff/admin view (try-locked ensure!/1 so a page mount never blocks; the ~1.1M-loan dataset is never bulk-seeded) plus an eager browse-path slice via priv/repo/seeds_provenance.exs. Fabricated rows carry details.fabricated=true; rebuilds delete only fabricated rows, skip any event a live command event already covers for the same subject, and never touch live events. The demo demonstrates the STRUCTURE of auditability; no factual claim is made about seeded people, tools, or places."
}

# --- Flows ------------------------------------------------------------
flow provenance.photo_chain {
  label: "Photo authenticity chain"
  status: observed
  confidence: 0.9
  entry: captured
  terminal: approved

  state captured
  state uploaded
  state reviewed
  state approved
  state visibility_changed

  step capture { actor: @actor.field_officer writes: [@provenance.event] }
  step review { actor: @actor.staff_auditor writes: [@provenance.event] }

  transition captured -> uploaded on photo_uploaded
  transition uploaded -> reviewed on photo_reviewed do [review]
  transition reviewed -> approved on photo_approved do [review]
  transition approved -> visibility_changed on photo_visibility_changed
}

flow provenance.story_chain {
  label: "Story authorship chain (authored -> optional AI rewording -> review)"
  status: observed
  confidence: 0.9
  entry: authored
  terminal: approved

  state authored
  state ai_reworded
  state reviewed
  state approved

  step author { actor: @actor.partner_staff writes: [@provenance.event] }
  step reword { actor: @actor.ai_model writes: [@provenance.event] }
  step review { actor: @actor.staff_auditor writes: [@provenance.event] }

  transition authored -> ai_reworded on story_ai_reworded do [reword]
  transition authored -> reviewed on story_reviewed do [review]
  transition ai_reworded -> reviewed on story_reviewed do [review]
  transition reviewed -> approved on story_approved do [review]
}

flow provenance.translation_chain {
  label: "Translation method chain (machine | template | human -> review)"
  status: observed
  confidence: 0.9
  entry: produced
  terminal: resolved

  state produced
  state resolved

  step produce { actor: @actor.ai_model writes: [@provenance.event] }
  step review { actor: @actor.staff_auditor writes: [@provenance.event] }

  transition produced -> resolved on translation_approved do [review]
  transition produced -> resolved on translation_rejected do [review]
}

# --- Views ------------------------------------------------------------
view loan_authenticity_timeline for @outcome.staff.authenticity_traced {
  label: "Staff/admin authenticity & provenance timeline on the loan profile"
  status: observed
  confidence: 0.95
  affordances: [summary_chips, grouped_timeline, actor_kind_badges, tool_lines, gps_lines, hash_chain_badges]
  reveals: [@provenance.event, @provenance.content_chain, @provenance.event_audience]
  commands: []
  metadata: { source: "lib/kiva_web/live/loan_live/show.ex", gate: "current_user.role in staff|admin", note: "Chips: event count, chain integrity, AI-touched, photo audience. Groups: photo / identity & consent / story / translations (per locale) / listing." }
}

# --- Open question ------------------------------------------------------
question question.provenance.non_admin_visibility on @provenance.event_audience {
  questionType: open_question
  ask: "Which provenance events (if any) open to partners, lenders, or the public — and does the photo audience field start enforcing rendering (the borrower-photo privacy story)?"
  whyItMatters: "Paul explicitly split data availability (built) from visibility policy (not decided). Opening the wrong events could expose GPS traces or reviewer identities."
  owner: "Paul Ericksen"
  neededBy: "Before any non-admin surface renders provenance or enforces photo privacy"
  blocking: []
  resolveWith: ["Product decision per event type; then a policy node + audience backfill, no schema change needed"]
  knowledge: {
    scope: ["provenance_events.visibility semantics"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-07-28"
    invalidatedBy: ["The visibility policy is decided and typed"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}
```
