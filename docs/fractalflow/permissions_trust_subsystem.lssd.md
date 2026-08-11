<!--
Canonical-For: lib/kiva/permissions.ex, lib/kiva/trust.ex, lib/kiva/audit.ex, lib/kiva/analytics.ex, lib/kiva_web/live/admin_live.ex
Status: ACTIVE
-->

# FractalFlow — Permissions & Trust Network Subsystem

Models the IMPLEMENTED permissions and trust network: permission groups + direct-grant outlier detection (`Kiva.Permissions.list_outliers`), the append-only audit trail, the trustee/endorsement/alternative-check graph, and the MOCK blockchain attestation (`sha256` proof, `mock-attest-v0`, `verified`) surfaced transparently per loan. Commands in the registry whose handlers return `{:not_implemented}` (or that exist only in product docs) are marked `asserted`.

2026-08-10: grammar upgrade (header, model status, outcomes, command wiring).
The staff decision-sweep journey that consumes the outlier queue lives in the
product contract (@story.staff.decision_sweep).

```lssd
model kiva.permissions_trust@0.3.0 {
  namespace: "kiva.permissions_trust"
  revision: "2026-08-10"
  status: observed
  confidence: 0.9
}

outcome outcome.admin.privilege_outliers_visible {
  label: "Nobody quietly holds power outside their role — outliers surface risk-first with revoke one step away"
  steps_max: 1
  vocabulary: actor
  summary: "Zero steps to see the outlier list (it is the answer), one step to revoke (admin-only, high-risk ceremony)."
  status: asserted
  confidence: 0.85
}

outcome outcome.lender.trust_verified {
  label: "A lender sees why to trust a loan — endorsements, checks, attestation — without leaving the profile"
  steps_max: 1
  vocabulary: actor
  summary: "The trust picture renders transparently on the loan profile (zero steps); one step reaches any deeper evidence. The attestation is explicitly mock (mock-attest-v0) — honesty is part of the outcome."
  status: asserted
  confidence: 0.85
}

module permissions.core {
  label: "Permissions core — groups, direct grants, outlier detection"
  status: observed
  confidence: 0.95
}

module trust.network {
  label: "Trust network — trustees, endorsements, checks, mock attestation"
  status: observed
  confidence: 0.95
}

module audit.trail {
  label: "Append-only audit trail (single mutation path writes here)"
  status: observed
  confidence: 0.95
}

# --- actors -------------------------------------------------------------

actor admin {
  label: "Admin — sole role permitted to revoke permissions"
  status: observed
  confidence: 0.95
}

actor staff {
  label: "Staff — runs review queues and the outlier dashboard"
  status: observed
  confidence: 0.95
}

actor trustee {
  label: "Trustee — local figure whose endorsement vouches for a borrower"
  status: observed
  confidence: 0.95
}

actor lender {
  label: "Lender — reads the transparent per-loan trust display"
  status: observed
  confidence: 0.95
}

# --- permission truths --------------------------------------------------

truth permission.definition {
  label: "A single capability (key, label, risk_level) grantable via group or direct"
  lifetime: system
  authority: { mode: admin, ref: @permissions.core }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: { table: "permissions", fields: ["key", "label", "risk_level"], default_risk: "low" }
}

truth permission.group {
  label: "Named bundle of permissions assigned to users (the role default)"
  lifetime: system
  authority: { mode: admin, ref: @permissions.core }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "permission_groups",
    joins: ["permission_group_permissions", "user_permission_groups"]
  }
}

truth permission.direct_grant {
  label: "Direct per-user grant bypassing the role group — the OUTLIER signal"
  lifetime: account
  authority: { mode: admin, ref: @permissions.core }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "user_permissions",
    fields: ["user_id", "permission_id", "granted_by_user_id", "reason"],
    written_by: "Kiva.Permissions.grant_direct/4",
    detected_by: "Kiva.Permissions.list_outliers/0"
  }
}

truth audit.event {
  label: "Append-only audit record written on every successful command"
  lifetime: archive
  authority: { mode: service, ref: @audit.trail }
  visibility: [staff, admin, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "audit_events",
    fields: ["actor_user_id", "actor_role", "event_type", "target_type", "target_id", "summary", "metadata"],
    append_only: true,
    written_by: "Kiva.Commands.execute/4 -> Kiva.Audit.record/1"
  }
}

# --- trust truths -------------------------------------------------------

truth analytics.distribution {
  label: "Live admin distribution aggregates (loans by status/country, funding by sector, translation coverage, AI usage)"
  lifetime: derived
  authority: { mode: service, ref: @permissions.core }
  visibility: [staff, admin, system]
  status: observed
  confidence: 0.95
  metadata: { impl: "Kiva.Analytics.overview/1", derivation: "GROUP BY aggregates over loans / loans_lc / ai_tool_calls; live, no snapshot read-model (demo scale)" }
}

truth trust.trustee {
  label: "Trustee identity (slug, country, status) with localized name/bio"
  lifetime: system
  authority: { mode: admin, ref: @trust.network }
  visibility: [lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { table: "trustees", translations: "trustee_lc", default_status: "active", admin_action: "Kiva.Trust.set_trustee_status/2 via the set_trustee_status command (suspend/reactivate)" }
}

truth trust.endorsement {
  label: "Trustee endorsement of a borrower's loan, localized statement"
  lifetime: system
  authority: { mode: human, ref: @trustee }
  visibility: [lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "trust_endorsements",
    translations: "endorsement_lc",
    default_status: "endorsed",
    localized_by: "Kiva.Localization.Resolver.resolve_public/2"
  }
}

truth trust.alternative_check {
  label: "Alternative verification check (type, status, detail) on a loan"
  lifetime: system
  authority: { mode: service, ref: @trust.network }
  visibility: [lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { table: "alternative_checks", default_status: "passed", statuses: ["passed", "pending"] }
}

truth trust.blockchain_attestation {
  label: "MOCK integrity attestation — sha256 proof over loan content"
  lifetime: system
  authority: { mode: service, ref: @trust.network }
  visibility: [lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "blockchain_attestations",
    mock: true,
    chain: "mock-attest-v0",
    attestation_type: "loan_integrity",
    proof: "sha256(loan:<id>:<content>) hex",
    verified: true,
    computed_by: "Kiva.Trust.attest/2",
    upsert_on: ["loan_id", "attestation_type"]
  }
}

# --- policies -----------------------------------------------------------

policy outlier_is_direct_grant on @permission.direct_grant {
  effect: require
  status: observed
  confidence: 0.95
  rule: "An outlier is a row in user_permissions: a direct per-user grant that bypasses the role's default group. list_outliers/0 joins users + permissions and orders by risk_level desc so staff see high-risk grants first."
}

policy revoke_is_admin_only on @permission.direct_grant {
  effect: require
  status: observed
  confidence: 0.95
  rule: "revoke_permission is admin-only / high-risk; the handler calls Kiva.Permissions.revoke_direct/2 (deletes the user_permissions row) and writes a permission.revoked audit event. The AdminLive outlier dashboard exposes a Revoke button per row."
}

policy audited_mutation_path on @audit.event {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Every consequential mutation converges on Kiva.Commands.execute/4, which re-runs role + required-input + eligibility gates and then writes one audit_events row. The AI never writes domain state directly."
}

policy transparent_trust_display on @trust.blockchain_attestation {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "The per-loan trust picture is shown transparently to lenders: trust-model label + explanation, endorsements, verification checks, and the attestation chain + truncated proof_hash with a 'verified' badge. The attestation is explicitly mock (mock-attest-v0)."
}

# --- flows --------------------------------------------------------------

flow permission_outlier_review {
  label: "Permission outlier review (admin dashboard)"
  status: observed
  confidence: 0.95
  entry: dashboard_closed
  terminal: reviewed

  state dashboard_closed
  state outliers_listed
  state inspecting
  state reviewed

  step list_outliers {
    actor: staff
    reads: [@permission.direct_grant, @permission.definition]
    writes: []
  }

  transition dashboard_closed -> outliers_listed on admin_opens_dashboard do [list_outliers]
  transition outliers_listed -> inspecting on row_selected
  transition inspecting -> reviewed on noted_as_expected
  transition inspecting -> reviewed on revoke_permission
  transition outliers_listed -> reviewed on no_outliers_present
}

flow loan_attestation {
  label: "Compute mock integrity attestation for a loan's content"
  status: observed
  confidence: 0.95
  entry: unattested
  terminal: attested

  state unattested
  state hashed
  state attested

  step compute_hash {
    actor: service
    reads: []
    writes: []
  }

  step persist_attestation {
    actor: service
    reads: []
    writes: [@trust.blockchain_attestation]
  }

  transition unattested -> hashed on attest_requested do [compute_hash]
  transition hashed -> attested on upsert_complete do [persist_attestation]
}

flow trust_display {
  label: "Render the transparent per-loan trust picture for a lender"
  status: observed
  confidence: 0.95
  entry: loan_opened
  terminal: trust_shown

  state loan_opened
  state trust_loaded
  state trust_shown

  step load_trust {
    actor: service
    reads: [@trust.endorsement, @trust.alternative_check, @trust.blockchain_attestation, @trust.trustee]
    writes: []
  }

  transition loan_opened -> trust_loaded on mount do [load_trust]
  transition trust_loaded -> trust_shown on render
}

# --- views --------------------------------------------------------------

view admin_analytics_dashboard for @permission_outlier_review {
  label: "Admin distribution analytics dashboard (AdminLive)"
  status: observed
  confidence: 0.95
  affordances: [stat_cards, grid]
  reveals: [@analytics.distribution]
  commands: []
  metadata: {
    source: "lib/kiva_web/live/admin_live.ex",
    panels: ["loans by status", "loans by country", "funding raised by sector", "translation coverage by locale", "AI tool calls allowed/denied"]
  }
}

view permission_outlier_dashboard for @story.staff.decision_sweep {
  label: "Permission outliers section (AdminLive)"
  status: observed
  confidence: 0.95
  affordances: [list, count_badge, risk_highlight, revoke_button, empty_state]
  reveals: [@permission.direct_grant, @permission.definition]
  commands: [revoke_permission]
  metadata: {
    source: "lib/kiva_web/live/admin_live.ex",
    columns: ["email", "role", "permission key", "risk"],
    empty: "No direct-grant outliers — everyone is within their role group."
  }
}

view audit_timeline for @permission_outlier_review {
  label: "Filterable audit timeline in AdminLive (event-type reconstruction)"
  status: observed
  confidence: 0.95
  affordances: [timeline, list, type_filter]
  reveals: [@audit.event]
  commands: []
  metadata: {
    source: "lib/kiva_web/live/admin_live.ex",
    via: "Kiva.Audit.list_events(limit:, event_type:) — ilike prefix filter; rows now reveal actor_role + target_type/target_id",
    reconstruct_target: "Kiva.Audit.list_for_target/2 (per-artifact history)"
  }
}

view ai_tool_call_inspector for @permission_outlier_review {
  label: "AI tool-call log + conversation drill-down in AdminLive"
  status: observed
  confidence: 0.95
  affordances: [table, allowed_badge, denial_reason, inspect_button, conversation_panel]
  reveals: [@audit.event]
  commands: []
  metadata: {
    source: "lib/kiva_web/live/admin_live.ex",
    list: "Kiva.AI.recent_tool_calls/1 (type / surface / op / allowed | denied+reason)",
    drill_down: "inspect_ai -> Kiva.AI.get_conversation!/1 (messages) + Kiva.AI.list_tool_calls/1 (request/response/denial per call)"
  }
}

view loan_trust_panel for @outcome.lender.trust_verified {
  label: "Trust & verification panel (LoanLive.Show)"
  status: observed
  confidence: 0.95
  affordances: [trust_model_explainer, endorsement_cards, check_list, attestation_card, verified_badge]
  reveals: [@trust.endorsement, @trust.alternative_check, @trust.blockchain_attestation, @trust.trustee]
  commands: []
  metadata: {
    source: "lib/kiva_web/live/loan_live/show.ex",
    shows: ["trust_model label + explanation", "endorsement trustee_name + statement", "check type/status/detail", "chain + truncated proof_hash + verified badge"]
  }
}

# --- commands -----------------------------------------------------------

view partner_trustee_management for @permission_outlier_review {
  label: "Admin partner & trustee review (suspend/reactivate) in AdminLive"
  status: observed
  confidence: 0.95
  affordances: [table, status_badge, suspend_button, reactivate_button]
  reveals: [@trust.trustee]
  commands: [set_partner_status, set_trustee_status]
  metadata: {
    source: "lib/kiva_web/live/admin_live.ex",
    partners: "Kiva.Partners.list_localized_partners/1",
    trustees: "Kiva.Trust.list_trustees/1",
    caveat: "suspension is a status flag; it does NOT cascade to hide the partner's loans in the demo"
  }
}

command set_partner_status {
  label: "Admin suspends/reactivates a field partner (status flag)"
  servesOutcome: @outcome.lender.trust_verified
  eligibility: ["Actor role admin"]
  effects: ["Partner status flag set (active | suspended); partner.status_changed audit event"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["admin"], required: ["partner_id", "status"], handler: "Kiva.Partners.set_status/2", caveat: "suspension does NOT cascade to hide the partner's loans in the demo" }
}

command set_trustee_status {
  label: "Admin suspends/reactivates a trustee (status flag)"
  servesOutcome: @outcome.lender.trust_verified
  eligibility: ["Actor role admin"]
  effects: ["Trustee status flag set (active | suspended); trustee.status_changed audit event"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["admin"], required: ["trustee_id", "status"], handler: "Kiva.Trust.set_trustee_status/2" }
}

command approve_translation {
  label: "Approve a localized content row (staff/admin)"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["Actor role staff | admin"]
  effects: ["Translation approved; audit event"]
  status: observed
  confidence: 0.95
  metadata: {
    risk: "medium",
    actors: ["staff", "admin"],
    handler: "Kiva.Translation.approve/3",
    wired_in: "lib/kiva_web/live/admin_live.ex",
    canonical_decl: "Full gate detail on the localization contract's declaration of this same command"
  }
}

command approve_loan_listing {
  label: "Publish a reviewed loan listing (staff/admin)"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["Actor role staff | admin", "Listing gates pass (translations, risk summary, review state)"]
  effects: ["Loan published to fundraising; partner notified; audit event"]
  status: observed
  confidence: 0.95
  metadata: {
    risk: "high",
    actors: ["staff", "admin"],
    handler: "Kiva.Lending.approve_listing/1",
    wired_in: "lib/kiva_web/live/admin_live.ex",
    canonical_decl: "Full gate detail on the loan_lifecycle contract's declaration of this same command"
  }
}

command revoke_permission {
  label: "Revoke a direct permission grant (admin-only)"
  servesOutcome: @outcome.admin.privilege_outliers_visible
  eligibility: ["Actor role admin (high risk)", "A direct grant exists for the target user"]
  effects: ["Direct grant removed (user_permissions row deleted)", "permission.revoked audit event"]
  status: observed
  confidence: 0.95
  metadata: {
    risk: "high",
    actors: ["admin"],
    in_registry: true,
    handler: "Kiva.Permissions.revoke_direct/2",
    note: "invalidate_sessions_if_needed is declared in the spec but not wired (demo)."
  }
}

command manage_permission_group {
  label: "Create/edit permission groups and their membership"
  status: asserted
  confidence: 0.8
  metadata: { in_registry: false, note: "Named in product docs; no registry entry and no handler." }
}

command manage_locale {
  label: "Administer supported locales / locale config"
  status: asserted
  confidence: 0.8
  metadata: { in_registry: false, note: "Named in product docs; no registry entry and no handler." }
}

command reset_demo_seed_state {
  label: "Reset the demo back to its seeded baseline"
  status: asserted
  confidence: 0.8
  metadata: { in_registry: false, note: "Named in product docs; no registry entry and no handler." }
}
```
