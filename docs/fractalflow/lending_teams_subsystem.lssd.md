<!--
Canonical-For: lib/kiva/teams.ex, lib/kiva/basket.ex, lib/kiva_web/live/team_live, lib/kiva_web/live/basket_live.ex
Status: ACTIVE
-->

# FractalFlow — Lending Teams & Lender Portfolio Subsystem

Models the implemented lending-teams, lend-on-behalf, lending-basket, and lender-portfolio code: team creation (team + source translation + owner membership + per-locale translation requests), a localized message board with on-demand machine translation of posts, lend-on-behalf-of-a-team, the basket-to-checkout fan-out that lends every item, and the lender impact loop (lend -> fund -> repay -> relend).

2026-08-10: grammar upgrade (header, model status, team outcome, command
wiring). The lender's first-person /portfolio journey lives in the loan
lifecycle contract (@story.lender.portfolio_checkin); this contract keeps the
teams/basket semantics.

```lssd
model kiva.lending_teams@0.3.0 {
  namespace: "kiva.lending_teams"
  revision: "2026-08-10"
  status: observed
  confidence: 0.9
}

module lending_teams.core {
  label: "Lending teams, basket, and lender portfolio"
  status: observed
  confidence: 0.95
}

outcome outcome.lender.lend_together {
  label: "Lenders lend as a team and watch shared impact grow"
  steps_max: 2
  vocabulary: actor
  summary: "Create a team (form + submit) or lend on its behalf (choose + confirm) — two actor steps either way; translation fan-out, owner enrollment, and totals happen inside the machine."
  status: asserted
  confidence: 0.85
}

actor actor.lender {
  label: "Authenticated lender (user.role == \"lender\")"
  status: observed
  confidence: 0.95
}

actor actor.team_owner {
  label: "Lender who created a team (membership role \"owner\")"
  status: observed
  confidence: 0.95
}

actor svc.translation {
  label: "Machine-translation + translation-request service"
  status: observed
  confidence: 0.95
  metadata: { modules: ["Kiva.Translation", "Kiva.Localization.Resolver"] }
}

# --- truths -------------------------------------------------------------

truth team.record {
  label: "Lending team (slug, owner, visibility, member_count, total_lent_cents)"
  lifetime: system
  authority: { mode: human, ref: @actor.team_owner }
  visibility: [public, lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "lending_teams",
    visibility_values: ["public", "private", "invite_only"],
    aggregates: ["member_count", "total_lent_cents"]
  }
}

truth team.profile_lc {
  label: "Per-locale team profile (name, tagline, description, welcome_post_template)"
  lifetime: system
  authority: { mode: human, ref: @actor.team_owner }
  visibility: [public, lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "lending_teams_lc",
    source_row: "is_source=true, translation_status=published",
    translation_status: ["draft", "published", "machine", "needs_review"]
  }
}

truth team.membership {
  label: "Team membership (user_id, role)"
  lifetime: account
  authority: { mode: service, ref: @lending_teams.core }
  visibility: [lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: { table: "lending_team_memberships", roles: ["owner", "member"] }
}

truth team.post {
  label: "Message-board post (moderation_status, source_locale_code)"
  lifetime: system
  authority: { mode: human, ref: @actor.lender }
  visibility: [public, lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: { table: "team_posts", default_moderation_status: "approved" }
}

truth team.post_lc {
  label: "Per-locale post body; on-demand machine translation rows"
  lifetime: system
  authority: { mode: service, ref: @svc.translation }
  visibility: [public, lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "team_posts_lc",
    machine_rows: "is_source=false, translation_status=machine, translated_from_lc_id set, source_hash recorded"
  }
}

truth lend.record {
  label: "A lending: user, loan, amount_cents, optional lending_team_id (lend-on-behalf)"
  lifetime: account
  authority: { mode: human, ref: @actor.lender }
  visibility: [lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: { table: "lendings", default_amount_cents: 2500, insert_only: "updated_at: false" }
}

truth basket.item {
  label: "Pending lending in a lender's basket (one row per user+loan)"
  lifetime: account
  authority: { mode: human, ref: @actor.lender }
  visibility: [lender, system]
  status: observed
  confidence: 0.95
  metadata: {
    table: "basket_items",
    upsert: "conflict_target [user_id, loan_id] replaces amount_cents",
    default_amount_cents: 2500
  }
}

truth loan.funding_progress {
  label: "Loan funded_amount_cents and status, advanced by each lending"
  lifetime: system
  authority: { mode: service, ref: @lending_teams.core }
  visibility: [public, lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: { funded_when: "funded_amount_cents >= loan_amount_cents -> status funded" }
}

truth portfolio.impact {
  label: "Derived lender impact: total lent, proportional repayments, available-to-relend"
  lifetime: account
  authority: { mode: service, ref: @lending_teams.core }
  visibility: [lender, system]
  status: observed
  confidence: 0.95
  metadata: {
    derivation: "returned = min(amount, round(loan_repaid * amount / max(funded,1)))",
    available_to_relend_cents: "equals returned_cents",
    distribution: ["countries", "sectors"]
  }
}

truth team.translation_request {
  label: "Per-target-locale translation request queued on creation / on-demand translate"
  lifetime: system
  authority: { mode: service, ref: @svc.translation }
  visibility: [staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    on_team_create: "one pending request per supported_locale != source",
    on_post_translate: "machine_translated request for team_post"
  }
}

# --- policies -----------------------------------------------------------

policy team_create_requires_lender on @team.record {
  effect: require
  status: observed
  confidence: 0.9
  rule: "The create-team form and portfolio stats render only when current_user.role == \"lender\" (TeamLive.Index lender? gate). Command handler runs server-side under the current_user."
}

policy source_locale_is_published_truth on @team.profile_lc {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "The author's source-locale row is inserted is_source=true / translation_status=published; all other locales begin as pending translation requests, not published rows."
}

policy posts_auto_approved on @team.post {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "add_post inserts moderation_status=approved with no review gate; no moderation queue is implemented."
}

policy on_demand_post_translation_is_idempotent on @team.post_lc {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "ensure_post_translation returns the existing row if the target locale already exists; otherwise it machine-translates from the source row once and records source_hash."
}

policy lend_advances_funding on @loan.funding_progress {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Every Portfolio.lend clamps funded_amount_cents to loan_amount_cents, flips status to funded at the threshold, and notifies all lenders exactly once on the funded crossing."
}

policy team_lend_increments_total on @team.record {
  effect: require
  status: observed
  confidence: 0.9
  rule: "When lending_team_id is present, the team's total_lent_cents is incremented by the lent amount (lend-on-behalf attribution)."
}

# --- flows --------------------------------------------------------------

flow team.creation {
  label: "Create lending team (create_lending_team)"
  status: observed
  confidence: 0.95
  entry: form_submitted
  terminal: team_published

  state form_submitted
  state team_inserted
  state source_translation_published
  state owner_enrolled
  state translation_requests_queued
  state team_published

  step insert_team {
    actor: @lending_teams.core
    writes: [@team.record]
  }
  step publish_source_lc {
    actor: @lending_teams.core
    writes: [@team.profile_lc]
  }
  step enroll_owner {
    actor: @lending_teams.core
    writes: [@team.membership]
  }
  step queue_translations {
    actor: @svc.translation
    writes: [@team.translation_request]
  }

  transition form_submitted -> team_inserted on create_team_called do [insert_team]
  transition team_inserted -> source_translation_published on source_lc_inserted do [publish_source_lc]
  transition source_translation_published -> owner_enrolled on owner_present do [enroll_owner]
  transition owner_enrolled -> translation_requests_queued on supported_locales_iterated do [queue_translations]
  transition translation_requests_queued -> team_published on audit_recorded
}

flow team.message_board {
  label: "Post to board + on-demand post translation"
  status: observed
  confidence: 0.95
  entry: viewing_board
  terminal: board_reloaded

  state viewing_board
  state post_written
  state post_persisted
  state translation_requested
  state translation_ready
  state board_reloaded

  step write_post {
    actor: @actor.lender
    writes: [@team.post, @team.post_lc]
  }
  step translate_post {
    actor: @svc.translation
    reads: [@team.post_lc]
    writes: [@team.post_lc, @team.translation_request]
  }

  transition viewing_board -> post_written on post_submitted
  transition post_written -> post_persisted on post_team_message do [write_post]
  transition viewing_board -> translation_requested on translate_post_clicked
  transition translation_requested -> translation_ready on ensure_post_translation do [translate_post]
  transition post_persisted -> board_reloaded on reload
  transition translation_ready -> board_reloaded on reload
}

flow lender.impact_loop {
  label: "Lend -> fund -> repay -> relend"
  status: observed
  confidence: 0.9
  entry: browsing_loans
  terminal: relending

  state browsing_loans
  state basket_assembled
  state lent
  state loan_funded
  state repaying
  state relendable
  state relending

  step add_to_basket {
    actor: @actor.lender
    writes: [@basket.item]
  }
  step checkout_lend_all {
    actor: @actor.lender
    reads: [@basket.item]
    writes: [@lend.record, @loan.funding_progress, @team.record]
  }
  step compute_impact {
    actor: @lending_teams.core
    reads: [@lend.record, @loan.funding_progress]
    writes: [@portfolio.impact]
  }

  transition browsing_loans -> basket_assembled on add_loan_to_basket do [add_to_basket]
  transition basket_assembled -> lent on checkout do [checkout_lend_all]
  transition browsing_loans -> lent on complete_demo_lend do [checkout_lend_all]
  transition lent -> loan_funded on funding_threshold_reached
  transition loan_funded -> repaying on repayment_scheduled
  transition repaying -> relendable on returns_accrue do [compute_impact]
  transition relendable -> relending on relend_clicked
}

# --- views --------------------------------------------------------------

view teams_hub for @team.creation {
  label: "Lending teams hub (TeamLive.Index): browse teams, portfolio stats, create-team form"
  status: observed
  confidence: 0.95
  affordances: [list, card, form, select, stats]
  reveals: [@team.record, @team.profile_lc, @portfolio.impact]
  commands: [create_lending_team]
}

view team_profile for @team.message_board {
  label: "Team profile + lending feed + message board (TeamLive.Show)"
  status: observed
  confidence: 0.95
  affordances: [card, form, list, translate_button, fallback_badge]
  reveals: [@team.profile_lc, @team.post, @team.post_lc, @lend.record]
  commands: [post_team_message]
}

view basket for @lender.impact_loop {
  label: "Lending basket: review amounts, remove, check out (lends all) (BasketLive)"
  status: observed
  confidence: 0.95
  affordances: [list, remove, total, checkout]
  reveals: [@basket.item]
  commands: [complete_demo_lend]
}

view portfolio for @lender.impact_loop {
  label: "My impact: loans touched, repayments, available-to-relend, country/sector distribution (PortfolioLive)"
  status: observed
  confidence: 0.95
  affordances: [stats, list, progress, relend_link, badge]
  reveals: [@portfolio.impact, @lend.record, @loan.funding_progress]
  commands: [complete_demo_lend]
}

# --- commands -----------------------------------------------------------

command create_lending_team {
  label: "Create team + source LC + owner membership + per-locale translation requests"
  servesOutcome: @outcome.lender.lend_together
  eligibility: ["Actor role lender"]
  effects: ["Team + published source profile + owner membership created", "Per-locale translation requests queued", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: { handler: "Kiva.Teams.create_team/2 via Commands.execute", returns: "%{slug: ...}" }
}

command post_team_message {
  label: "Add an approved board post in the author's source locale"
  servesOutcome: @outcome.lender.lend_together
  eligibility: ["Actor role lender"]
  effects: ["Approved post + source LC row created (on-demand translation for readers)"]
  status: observed
  confidence: 0.95
  metadata: { handler: "Kiva.Teams.add_post/4 via Commands.execute" }
}

command complete_demo_lend {
  label: "Record a lending, advance loan funding, attribute to team if lending_team_id set"
  servesOutcome: @outcome.lender.principal_back_to_relend
  eligibility: ["Actor role lender", "Loan status fundraising", "$25-multiple amount"]
  effects: ["Lending recorded; funding advances", "Team total incremented when lending on a team's behalf"]
  status: observed
  confidence: 0.95
  metadata: {
    handler: "Kiva.Portfolio.lend/4 via Commands.execute",
    invoked_by: "BasketLive checkout (per item) and direct loan lend",
    canonical_decl: "Full gate detail on the loan_lifecycle contract's declaration of this same command"
  }
}

command add_loan_to_basket {
  label: "Add/update a loan in the lender's basket (upsert by user+loan)"
  servesOutcome: @outcome.lender.principal_back_to_relend
  eligibility: ["Actor role lender", "Loan status fundraising"]
  effects: ["Basket row upserted (one per user+loan; amount replaced)"]
  status: observed
  confidence: 0.9
  metadata: { handler: "Kiva.Basket.add/3", note: "basket context implemented; checkout fans out to complete_demo_lend" }
}
```
