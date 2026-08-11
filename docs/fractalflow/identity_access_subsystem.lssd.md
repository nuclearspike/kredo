<!--
Canonical-For: lib/kiva/accounts, lib/kiva_web/plugs, lib/kiva_web/controllers/session_controller.ex
Status: ACTIVE
-->

# FractalFlow — Identity & Access Subsystem

2026-08-10: grammar upgrade (header, model status, sign-in outcome) and one
truth filed backward by the encouragement sender-reveal ruling:
`user.profile_public` does not exist in the schema yet — the reveal policy
forces it (@decision.encouragement_sender_reveal in the messaging contract).

```lssd
model kiva.identity_access@0.2.0 {
  namespace: "kiva.identity_access"
  revision: "2026-08-10"
  status: observed
  confidence: 0.9
}

module identity.access {
  label: "Identity and access"
  status: observed
  confidence: 0.95
}

outcome outcome.actor.signed_in {
  label: "An actor signs in and lands where their work is, as who they are"
  steps_max: 1
  vocabulary: actor
  summary: "One step (submit credentials; the demo quick-fill removes typing). Role-scoped landing and the account's default locale are supposed to arrive with the session — the locale half currently breaks (@finding.localization.locale_precedence_defeats_default)."
  status: asserted
  confidence: 0.9
}

truth user.role {
  label: "Actor role for authorization and schema scoping"
  lifetime: account
  authority: { mode: admin, ref: @identity.access }
  visibility: [system, staff]
  status: observed
  confidence: 0.95
  metadata: { values: ["borrower", "lender", "partner", "staff", "admin"] }
}

truth user.session {
  label: "Authenticated session (user_id in signed session)"
  lifetime: session
  authority: { mode: service, ref: @identity.access }
  visibility: [system]
  status: observed
  confidence: 0.95
}

truth user.default_locale {
  label: "User default locale preference"
  lifetime: account
  authority: { mode: human, ref: @actor.lender }
  visibility: [public, system]
  status: observed
  confidence: 0.95
  metadata: { note: "Currently shadowed at first login by session write-back — @finding.localization.locale_precedence_defeats_default (audit H2)." }
}

truth user.profile_public {
  label: "Lender-controlled public-profile flag (drives cross-actor identity reveals)"
  lifetime: account
  authority: { mode: human, ref: @actor.lender }
  visibility: [public, borrower, lender, staff, system]
  status: asserted
  confidence: 0.9
  sourceRefs: [@dashboard_first_person_audit]
  metadata: { note: "Does not exist in the schema yet — forced backward by @decision.encouragement_sender_reveal (audit Q1): sender identity and the borrower thank/return edge cross only when this flag is true. Default private. Lands with @product.sender_reveal (product ledger)" }
}

policy role_scoped_routes on @identity.access {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Role-scoped routes re-check the role server-side via on_mount/plug; the client is never the boundary."
}

question question.identity.login_journey_growth on @outcome.actor.signed_in {
  questionType: open_question
  ask: "Grow the sign-in story (stages, demo quick-fill decision, failure/lockout path) when identity work is next touched — the outcome ring deliberately stops here for now."
  whyItMatters: "The outcome exists so the login view derives from an outcome, not the flow (Law 14); its serving story is deferred rather than faked."
  owner: "Paul Ericksen"
  neededBy: "Next substantive identity/access change"
  blocking: ["Story-derived rework of the login surface"]
  resolveWith: ["Touched-story pass over Kiva.Accounts + session controller"]
  knowledge: {
    scope: ["identity_access journey depth"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-08-10"
    invalidatedBy: ["The sign-in story is authored"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}

flow identity.login {
  label: "Session login"
  status: observed
  confidence: 0.95
  entry: anonymous
  terminal: authenticated

  state anonymous
  state credentials_submitted
  state authenticated
  state rejected

  step verify_credentials {
    actor: @identity.access
    reads: [@user.role]
    writes: [@user.session]
  }

  transition anonymous -> credentials_submitted on submit_login
  transition credentials_submitted -> authenticated on credentials_valid do [verify_credentials]
  transition credentials_submitted -> rejected on credentials_invalid
}

view login_form for @outcome.actor.signed_in {
  label: "Login form with demo-account quick fill"
  status: observed
  confidence: 0.95
  affordances: [form, submit]
  reveals: [@user.session]
  commands: [log_in, log_out]
}
```
