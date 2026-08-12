<!--
Canonical-For: lib/kiva/lending.ex, lib/kiva/loan_applications.ex, lib/kiva/portfolio.ex, lib/kiva_web/live/portfolio_live.ex, lib/kiva_web/live/partner_live.ex, lib/kiva_web/live/partner/repayments_live.ex, lib/kiva_web/live/loan_live
Status: ACTIVE
-->

# FractalFlow — Loan Lifecycle Subsystem

Models the implemented loan lifecycle in `Kiva.Lending` / `Kiva.LoanApplications` /
`Kiva.Portfolio`, from a partner draft through staff review, fundraising, funding,
and the repayment loop that returns principal proportionally to lenders. Every mutation
converges on `Kiva.Commands` (the single audited mutation path). Status labels are
honest evidence: `observed` = verified in code read; `asserted` = declared (status
enum, registry, or `@public_statuses`) but no code writes/transitions it.

2026-07-26: doc-fidelity catch-up for the 2026-07-07 work (commits 044f9b2, 60e21c8) — lending invariants recorded as typed constraints, the 30-day repayment-schedule counterexample, the rebuilt lender impact dashboard, and the open received-bucketing question.

2026-08-10: grammar upgrade to the current LSSD spec + the v1.12 first-person
layer for the two dashboard journeys this subsystem owns — the lender's
/portfolio return and the partner's /partner morning. Stage records carry
interior monologues and ranked question stacks seeded from
docs/storytime/dashboard_first_person_audit_2026-08-10.md; both journeys are
explicitly `practitioner_unvalidated` (audit cold-reads are agent_walked
evidence, not a practitioner gate). The audit's product rulings on bulk
collections and the risk-details page live here as decision_records; the
truths they force (loss attribution, arrears aging, fundraising deadline,
schedule item terms) are filed backward as schema needs.

```lssd
model kiva.loan_lifecycle@0.4.0 {
  namespace: "kiva.loan_lifecycle"
  revision: "2026-08-11"
  status: observed
  confidence: 0.9
}

module loan.lifecycle {
  label: "Loan lifecycle"
  status: observed
  confidence: 0.95
}

actor actor.partner {
  label: "Field partner (authors & submits loans, remits repayments)"
  status: observed
  confidence: 0.95
  summary: "Embodied 2026-08-10 for the /partner first-person layer. Lexicon and monologue are DRAFTED from the dashboard audit's cold-reads (persona Ana, es) — not practitioner-harvested."
  domainVocabulary: ["cobrar hoy", "solicitud", "devuelta por revisión", "campaña", "prestataria"]
  lexicon: [
    { contract_term: "repayments due today", actor_term: "lo que cobro hoy", register_person: "usted, professional es", banned: false },
    { contract_term: "changes_requested", actor_term: "devuelta por revisión (con el motivo)", register_person: "usted", banned: false },
    { contract_term: "draft #<internal id>", actor_term: "la solicitud de <nombre> — <título>", banned: true, homonym_warning: "a raw id as a label is unrecognizable (audit H3); identity is name + title + date + amount" },
    { contract_term: "fundraising / fundraising_ends_at", actor_term: "campaña — vence el <fecha>", banned: false },
    { contract_term: "lifecycle / status enum values", actor_term: "(never shown raw)", banned: true }
  ]
  lexiconProvenance: "Drafted 2026-08-10 from the dashboard audit; verbatim_sentences empty until a real partner narrates"
  knowledgeBoundary: {
    availableNow: ["What is due today (count and amount)", "Which submissions review returned and why", "Which campaigns are near their deadline and how funded they are"]
    unavailableYet: ["Whether staff will approve a pending submission", "Tomorrow's collections until schedules roll"]
  }
  perceptualChannels: [visual, textual]
  representativeWork: "Morning operational check-in over ~77K loans with 1,992 repayments due (audit persona Ana)"
  interruptionAndTimeConstraints: ["Field interruptions; the morning check-in must survive being resumed hours later"]
  authorityAndRiskBoundary: ["Authors and submits applications; records collections and disbursals; cannot approve own listings"]
  evidenceLevel: agent_walked
}

actor actor.staff {
  label: "Staff / admin reviewer (approves listing, requests changes)"
  status: observed
  confidence: 0.95
}

actor actor.lender {
  label: "Lender (funds loans, is repaid a proportional share of principal — never more)"
  status: observed
  confidence: 0.95
  summary: "Embodied 2026-08-10 for the /portfolio first-person layer. Lexicon and monologue are DRAFTED from the dashboard audit's cold-reads — no practitioner has narrated yet; harvest verbatims at the next practitioner-gate session."
  domainVocabulary: ["my money", "came back", "behind schedule", "lost", "lend again"]
  lexicon: [
    { contract_term: "repayment.lender_principal_returned_cents", actor_term: "money that came back", register_person: "second person, plain en", banned: false },
    { contract_term: "available_to_relend_cents", actor_term: "ready to lend again", register_person: "second person", banned: false },
    { contract_term: "delinquent", actor_term: "behind schedule", register_person: "second person", banned: true, homonym_warning: "industry jargon that reads as a moral judgment of the borrower" },
    { contract_term: "defaulted / loss attribution", actor_term: "lost", register_person: "second person", banned: false, homonym_warning: "'default' also reads as 'standard setting' to non-finance readers — prefer 'lost'" },
    { contract_term: "principal / arrears / exposure", actor_term: "(never shown)", banned: true },
    { contract_term: "return / returns / yield / interest / earnings / ROI", actor_term: "money that came back", banned: true, homonym_warning: "FINANCE VOCABULARY THAT ASSERTS A FALSEHOOD: lending here pays the lender 0% (@policy.lending.zero_interest_to_lender). 'Returns' claims a gain that cannot exist. Say 'came back', 'repaid to you', or 'ready to lend again'. This row exists because the term leaked into four contract node ids and one hero string before 2026-08-11." }
  ]
  lexiconProvenance: "Drafted 2026-08-10 from the dashboard audit; verbatim_sentences deliberately empty until a real lender narrates (v1.12 harvest discipline)"
  knowledgeBoundary: {
    availableNow: ["Totals lent and returned", "Which loans sit behind schedule", "Amount ready to relend"]
    unavailableYet: ["Whether a behind-schedule loan will ultimately repay", "Final loss on any active loan"]
  }
  perceptualChannels: [visual, textual]
  representativeWork: "Returning minutes-long session over a 1,408-lending portfolio with money available to relend (audit persona Morgan)"
  interruptionAndTimeConstraints: ["Casual short visits; must re-orient from the hero alone"]
  authorityAndRiskBoundary: ["Chooses where own money goes; cannot see other lenders' holdings or mutate loans"]
  evidenceLevel: agent_walked
}

actor actor.borrower {
  label: "Borrower (subject of the loan; repays via the partner)"
  status: observed
  confidence: 0.9
}

# --- Capabilities -----------------------------------------------------
capability loan.authoring {
  label: "Partner authors a draft loan and its source-locale content"
  servesOutcome: @outcome.partner.loan_listed
  status: observed
  confidence: 0.95
}

capability loan.review {
  label: "Staff reviews submitted loans and gates publication"
  servesOutcome: @outcome.staff.decisions_cleared
  status: observed
  confidence: 0.95
}

capability loan.fund {
  label: "Lenders fund a fundraising loan until fully funded"
  servesOutcome: @outcome.lender.principal_back_to_relend
  status: observed
  confidence: 0.95
}

capability loan.repay {
  label: "Partner remits scheduled repayments; lenders relend what came back"
  servesOutcome: @outcome.partner.day_collected
  status: observed
  confidence: 0.95
}

# --- Outcomes (2026-08-10: first actor outcomes for this subsystem) ----
outcome outcome.lender.principal_back_to_relend {
  label: "A returning lender sees what their money did and puts repayments back to work"
  steps_max: 2
  vocabulary: actor
  summary: "Arrive answered — the hero states lent / came back / ready to lend again plus one honest risk line — then relending is choose + confirm: two actor steps, the confirm ceremony earned by lending being the product's one money-moving act. The outcome is impact plus recycled principal; there is no yield (see @policy.lending.zero_interest_to_lender)."
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
}

outcome outcome.partner.day_collected {
  label: "A partner knows what to collect today and records the day's collections as one batch"
  steps_max: 2
  vocabulary: actor
  summary: "The workspace opens on today (count + amount due); recording is day-batch preview -> confirm through the registry (@decision.partner_bulk_collections), never 1,992 single clicks. Per-loan recording remains the exception path."
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
}

outcome outcome.partner.loan_listed {
  label: "A complete application becomes a fundraising listing the partner can track"
  steps_max: 3
  vocabulary: actor
  summary: "Start (or resume), complete the draft, submit. Staff review happens inside the wait; a bounce comes back with the reviewer's reason attached (@loan.changes_requested_reason). The authoring/review capabilities serving this are observed in code; the outcome framing is new."
  status: asserted
  confidence: 0.9
}

# --- Truths -----------------------------------------------------------
truth loan.status {
  label: "Loan lifecycle status (canonical state machine field)"
  lifetime: system
  authority: { mode: service, ref: @loan.lifecycle }
  visibility: [borrower, lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    observed_values: ["draft", "submitted_to_staff", "changes_requested", "fundraising", "funded", "completed"],
    asserted_values: ["staff_review", "funded_disbursed", "repaying"],
    seed_provided_values: ["repaying", "delinquent", "defaulted"],
    note: "staff_review is queried/gated but never written; funded_disbursed + repaying are loan-STATUS values with no transition that sets them. Disbursal is tracked on the SEPARATE disbursal_status field (now written by record_disbursal); record_repayment advances funded -> completed without ever setting a repaying status. Seeds additionally write repaying/delinquent/defaulted directly for demo data; browse filters, status badges, and the portfolio dashboard handle all of them."
  }
}

truth loan.amount_cents {
  label: "Requested loan principal in cents (loan_amount_cents)"
  lifetime: system
  authority: { mode: human, ref: @actor.partner }
  visibility: [borrower, lender, partner, staff, system]
  status: observed
  confidence: 0.95
}

truth loan.funded_amount_cents {
  label: "Cumulative funded cents; reaching loan_amount_cents flips status to funded"
  lifetime: system
  authority: { mode: service, ref: @loan.fund }
  visibility: [borrower, lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { writer: "Kiva.Portfolio.lend/4", funded_percent: "min(100, funded/amount*100)" }
}

truth loan.disbursal_status {
  label: "Disbursal state (pre_disbursed | post_disbursed | direct_disbursal_pending | direct_disbursed)"
  lifetime: system
  authority: { mode: service, ref: @loan.lifecycle }
  visibility: [lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    note: "Advanced by record_disbursal (Kiva.Lending.record_disbursal/1): pre_disbursed -> post_disbursed, direct_disbursal_pending -> direct_disbursed; stamps disbursed_at and reveals to lenders. Orthogonal to loan.status. Revealed on the loan profile (disbursal_label badge)."
  }
}

truth loan.story_text {
  label: "Localizable loan content (title, story, use, repayment + risk summaries)"
  lifetime: system
  authority: { mode: human, ref: @actor.partner }
  visibility: [public, borrower, lender, partner, staff, system]
  recognized_by: ["borrower name", "loan title", "photo thumbnail", "amount", "started/updated date — never a raw internal id (audit H3)"]
  status: observed
  confidence: 0.95
  metadata: { storage: "loans_lc rows (is_source true for the partner's source locale)", translation_status: ["draft", "machine", "approved", "rejected"] }
}

truth loan.fundraising_ends_at {
  label: "Fundraising deadline for a listed loan (campaign end)"
  lifetime: system
  authority: { mode: service, ref: @loan.lifecycle }
  visibility: [public, borrower, lender, partner, staff, system]
  status: asserted
  confidence: 0.9
  sourceRefs: [@dashboard_first_person_audit]
  metadata: { note: "The 2026-08-10 audit observed loans.fundraising_ends_at in the schema with NO surface anywhere. The expiring-underfunded answer in @stage.partner.morning_checkin and the days-left line in the borrower headline both hang on it; contract-level code verification pending the next code touch." }
}

truth repayment_schedule.item_terms {
  label: "Schedule item terms: due_on date and per-item amount_cents"
  lifetime: system
  authority: { mode: service, ref: @loan.repay }
  visibility: [lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { note: "Already exercised by @evidence.lending.schedule_spacing (create_repayment_schedule writes due_on and amounts); declared 2026-08-10 because collections rows must reveal them for the recording decision (audit M4, @decision.partner_bulk_collections)." }
}

truth loan.loss_attribution {
  label: "Per-loan principal lost to default, attributable to a lender's share"
  lifetime: account
  authority: { mode: derived, ref: @loan.repay }
  visibility: [lender, staff, system]
  status: asserted
  confidence: 0.85
  sourceRefs: [@dashboard_first_person_audit]
  metadata: { note: "Does not exist yet — forced backward by the risk-details ruling (@decision.lender_risk_details_page) and the lender stack entry 'Is any of it in trouble?'. Derivation sketch: unpaid lender share on defaulted loans." }
}

truth repayment.arrears_aging {
  label: "Overdue aging buckets over unpaid schedule items (per loan; summable per lender or partner)"
  lifetime: account
  authority: { mode: derived, ref: @loan.repay }
  visibility: [lender, partner, staff, system]
  status: asserted
  confidence: 0.85
  sourceRefs: [@dashboard_first_person_audit]
  metadata: { note: "Forced by BOTH rulings: risk-details slices (lender) and collections-row aging (partner). Buckets over due_on vs today on unpaid items; month math must respect @counterexample.lending.calendar_month_schedules (30-day spacing, not calendar months)." }
}

truth loan.risk_summary_public {
  label: "Public risk/trust summary; gates listing approval"
  lifetime: system
  authority: { mode: human, ref: @actor.partner }
  visibility: [public, lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { note: "submit_for_review backfills a default if the partner left it blank, so the risk_summary_present gate passes." }
}

truth repayment_schedule.item_status {
  label: "Repayment schedule item status (scheduled -> paid)"
  lifetime: system
  authority: { mode: service, ref: @loan.repay }
  visibility: [lender, partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { values: ["scheduled", "paid"], advanced_by: "Kiva.Lending.record_repayment/1 (earliest due scheduled item -> paid, sets paid_on)" }
}

truth repayment.lender_principal_returned_cents {
  label: "Principal repaid to a lender = min(lent, repaid * lent / funded) — capped at what they lent"
  lifetime: account
  authority: { mode: service, ref: @loan.repay }
  visibility: [lender, system]
  status: observed
  confidence: 0.95
  enforces: @policy.lending.zero_interest_to_lender
  metadata: {
    computed_in: "Kiva.Portfolio.portfolio_summary/1 + impact_summary/2 + impact_groups/4 + filtered_totals/2 (min/LEAST cap); expected_repayment_series/2 + late_and_upcoming/2 divide the lender share by GREATEST(funded, scheduled_total) so the projection cannot exceed principal either",
    note: "available_to_relend_cents == returned_cents; no separate relend ledger."
  }
}

policy policy.lending.zero_interest_to_lender {
  label: "Lenders earn 0% — principal back at best, often less"
  appliesTo: [@actor.lender, @portfolio.impact, @repayment.lender_principal_returned_cents]
  rule: "No surface, string, projection, or aggregate may show a lender receiving more than they lent. The best possible outcome is 100% of principal returned; defaults, arrears, and (where modeled) currency loss make the realistic outcome less. A borrower's repayment schedule MAY exceed the loan principal — the field partner charges the borrower interest and fees to sustain its operations — but that overage belongs to the partner and never crosses into the lender's plane."
  rationale: "This mirrors real Kiva-style lending, where the lender's return is impact, not yield. Showing any gain is not a UI blemish but a false financial claim."
  enforcement: "Read paths cap with min/LEAST; projection paths divide by GREATEST(funded, scheduled_total). Regression test: 'the repayment projection never pays a lender more than they lent' (test/kiva/portfolio_test.exs) — proven to fail before the 2026-08-11 fix (projected 100_000 on 25_000 lent)."
  status: observed
  confidence: 1.0
}

evidence evidence.portfolio.projection_exceeded_principal {
  kind: measurement
  occurredAt: "2026-08-11"
  subject: @portfolio.impact
  method: "Owner flagged the 'portfolio_return' node name; vocabulary sweep escalated to a math check. SQL over the seeded dev database plus a bite-proof regression test."
  observation: "769 of 98,141 scheduled loans (0.8%) carry installments totalling more than their principal, worst case 144% ($250 lent, $360 scheduled over 36 months) — an artifact of the seed/generator formula max(1000, amount/term). The four aggregate read paths already capped the lender's share with min/LEAST, but expected_repayment_series/2 and late_and_upcoming/2 did not: the demo lender's chart projected 100.1% of principal back ($4,928,101 on $4,925,000 lent), and the isolated test case projected 300% ($100,000 on $25,000)."
  provenance: { doc: "session 2026-08-11; test/kiva/portfolio_test.exs" }
  scope: ["Lender chart + stat chips before the GREATEST(funded, scheduled_total) fix"]
  status: observed
  confidence: 1.0
}

finding finding.portfolio.uncapped_projection_implied_yield {
  claim: "The lender's repayment projection implied a yield that cannot exist: two of six computation paths divided the lender's share by funded principal alone, so an over-scheduled loan projected more coming back than went out."
  basedOn: [@evidence.portfolio.projection_exceeded_principal]
  scope: ["expected_repayment_series/2 and late_and_upcoming/2"]
  supports: ["@policy.lending.zero_interest_to_lender needs mechanical enforcement, not convention — four paths had the cap and two did not"]
  contradicts: []
  limitations: ["The underlying data still over-schedules some loans; whether that overage is modeled deliberately as partner interest or flattened is @question.lending.model_partner_interest"]
  invalidatedBy: ["Fixed 2026-08-11 by dividing the lender share by GREATEST(funded, scheduled_total); regression test bites"]
  strength: conclusive
  status: observed
  confidence: 1.0
}

policy policy.listing.every_language_before_live {
  label: "A listing goes live in every language or not at all"
  appliesTo: [@approve_loan_listing, @loan.lifecycle]
  rule: "A loan may not enter fundraising until every supported locale has a language-content row AND every non-source row has been reviewed (approved or published). The source row is exempt from the review bar because it is the original rather than a translation; listing review is what approves it, so publishing promotes it from draft to published in the same step. Machine output and needs_review are displayable but are NOT publishable."
  rationale: "Publishing in a subset of languages puts a borrower's story in front of lenders who cannot read it, and asks them to back a story they were shown only a machine draft of. The registry has declared this gate since the first phase as translations_ready_or_fallback_allowed, but the check returned :ok unconditionally \u2014 a contract obligation that no code enforced. Owner ruling 2026-08-11: make it real."
  enforcement: "Eligibility check all_locales_translated on @approve_loan_listing, evaluated after partner_review_complete and risk_summary_present so an unsubmitted loan still reports the reason a reviewer expects. Kiva.Lending.approve_listing/2 repeats the check and returns {:error, {:translations_pending, locales}} so no caller can publish around the command layer. The reviewer is shown the outstanding languages by native name. Regression tests: 'a listing cannot go live while a language is unreviewed' (test/kiva/admin_ops_test.exs) and 'approving names the languages that are still unreviewed' (test/kiva_web/live/admin_live_test.exs)."
  status: observed
  confidence: 1.0
}

finding finding.listing.declared_gate_was_never_enforced {
  claim: "A high-risk command declared an eligibility gate that its implementation answered :ok to unconditionally, so the contract read as enforced while nothing enforced it."
  basedOn: [@evidence.listing.unreviewed_translations_went_live]
  scope: ["approve_loan_listing before 2026-08-11"]
  supports: ["Named eligibility checks need a test each, or the registry becomes decoration \u2014 the module's own docstring says unknown checks default to :ok, which makes a typo in a check name silently permissive"]
  contradicts: []
  limitations: ["The other named checks in the registry have not been audited for the same gap"]
  invalidatedBy: ["all_locales_translated implemented and covered by tests that fail without it"]
  strength: conclusive
  status: observed
  confidence: 1.0
}

evidence evidence.listing.unreviewed_translations_went_live {
  kind: measurement
  occurredAt: "2026-08-11"
  subject: @loan.lifecycle
  method: "Read the command registry against its Eligibility implementation; counted live loans against the bar the registry claimed."
  observation: "The stub returned :ok for every caller, commented 'fallback is allowed in the demo'. 2,396 of 3,992 fundraising loans in the seeded database carry at least one machine or needs_review translation, so the majority of live listings had never met the declared bar. Those rows predate the gate and are left as they are: the rule governs transitions, not history."
  provenance: { doc: "session 2026-08-11" }
  scope: ["Seeded demo database at 1.1M loans"]
  status: observed
  confidence: 1.0
}

capability loan.browse {
  label: "Find a loan worth backing (KivaWeb.LoanLive.Index)"
  status: observed
  confidence: 0.9
  refines: @loan.fund
  metadata: {
    surface: "lib/kiva_web/live/loan_live/index.ex",
    affordances: ["free-text search", "sector chips", "country filter", "sort", "cursor pagination"],
    locale_scoped: "results are matched against the reader's own language rows — @decision.search.scoped_to_readers_language",
    note: "Declared 2026-08-12. Two search policies had pointed at @loan.browse since they were written, but the capability itself was never defined — the dangling reference was the only trace of it."
  }
}

policy policy.search.word_beginnings_only {
  label: "Loan search matches word beginnings, and one character is not a search"
  appliesTo: [@portfolio.impact, @loan.browse]
  rule: "A search term matches where a WORD STARTS with it, in the ONE translation the reader is shown. A term buried inside a longer word does not match. Terms shorter than two characters are treated as no filter rather than as a search for everything. User input is regex-escaped before it reaches the pattern. Which row the reader is shown mirrors @Resolver: the requested locale when it has a display-eligible row, otherwise the English fallback; draft/rejected/stale rows are searched no more than they are displayed."
  rationale: "Substring matching cannot express what a searcher means. Someone typing toward 'catering' passes through 'cat', and ILIKE '%cat%' answers with every education loan because 'education' contains those letters — reported from the loans page 2026-08-11."
  enforcement: "Kiva.Lending.search_loans/2 (shared by the browse page, the status counts, and the compatibility API). Regression test: 'search matches word beginnings, not substrings buried in other words' (test/kiva/lending_test.exs), proven to fail before the fix."
  status: observed
  confidence: 1.0
}

policy policy.search.submit_preserves_the_search {
  label: "Running a search never clears it"
  appliesTo: [@loan.browse]
  rule: "Every filter form handled by phx-change also declares phx-submit, so pressing Enter is handled in place. A form without it is submitted natively by the browser, which remounts the LiveView and discards both the entered text and the results it produced."
  rationale: "Reported 2026-08-11: pressing Enter on the loans page emptied the search box and returned the unfiltered list. The same omission was present on the audit filter, the partner repayment search, and the portfolio filters; all four were corrected together."
  enforcement: "Regression test: 'submitting the search keeps the term and the filtered results' (test/kiva_web/live/loan_live_test.exs)."
  status: observed
  confidence: 1.0
}

decision_record decision.search.scoped_to_readers_language {
  label: "Search reads only the language the reader is shown"
  status: observed
  confidence: 1.0
  summary: "Loan search matches the resolved translation only, not all five. Searching an English word no longer returns a card whose visible text lacks it, and vice versa: 'tejido' answers a Spanish reader and nobody else. The English fallback is honoured, so a reader whose language has no display-eligible row searches the English text they are actually shown. Applies to the browse page, its status counts, and the compatibility API's q parameter, which now receives the caller's locale. The partner's repayment lookup is deliberately NOT scoped: it is an operational search for a known person, where matching a name in any translation is recall the partner wants. Ruling: owner, 2026-08-11 ('scope search to the reader's language'). Enforced by 'search reads the language the reader is shown, including the English fallback' (test/kiva/lending_test.exs), proven to fail against the unscoped query."
}

evidence evidence.portfolio.dashboard_query_budget {
  kind: measurement
  occurredAt: "2026-08-11"
  subject: @portfolio.impact
  method: "Timed each /portfolio query five times against the dev database at generated scale (1.1M loans, 98k schedules, a 1,408-lending demo portfolio); EXPLAIN ANALYZE on the chart query."
  observation: "Median per query: expected_repayment_series 244ms (194ms before the 0%-cap fix), late_and_upcoming 251ms, impact_summary 281ms. repayment_schedules carried NO index on loan_id until 2026-08-11, so every schedule lookup sequential-scanned 98k rows; the index landed with this measurement. The page's Tier-1 answer (hero totals) is gated behind Tier-2 chart aggregates."
  provenance: { doc: "session 2026-08-11 benchmark; migration 20260811055455" }
  scope: ["/portfolio at generated scale; small seeded portfolios are unaffected"]
  status: observed
  confidence: 0.9
}

finding finding.portfolio.tier2_aggregates_block_tier1 {
  claim: "/portfolio misses the interaction budget at generated scale: roughly three quarters of a second of chart and distribution aggregates load before the hero the lender actually came for."
  basedOn: [@evidence.portfolio.dashboard_query_budget]
  scope: ["Lender dashboard; the same shape likely affects the partner workspace, which loads a full overview on mount"]
  supports: ["Tier-1-first loading: paint the hero from cheap indexed aggregates, stream the chart and facets in after"]
  contradicts: []
  limitations: ["Pre-existing and broader than any single query: the 0%-cap fix added ~50ms of the total and is not the cause. Remedies not yet chosen — storing a scheduled_total_cents per schedule would erase the cap's cost and more, but the page needs a whole-surface pass, not one query tuned."]
  invalidatedBy: ["A /portfolio performance pass that paints Tier-1 independently of the aggregates"]
  strength: supported
  status: observed
  confidence: 0.9
}

question question.lending.model_partner_interest on @repayment_schedule.item_terms {
  questionType: open_question
  question: "Should the demo model the field partner's interest explicitly — a borrower schedule of principal + a stated rate, with the surfaces explaining that the overage sustains the partner and never reaches the lender — or should schedules total exactly the principal (0% everywhere, simplest)?"
  whyItMatters: "Today's over-scheduling is accidental (the generator's max(1000, amount/term) floor), not a designed rate, yet it is closer to real microfinance than a flat 0% schedule. Modeling it deliberately would let the product explain the single most misunderstood fact about this kind of lending: the borrower pays interest, the lender does not. Flattening is a two-line generator change."
  blocks: ["The borrower's repayment copy and the lender risk-details page's 'where did the rest go' breakdown"]
  status: asserted
  confidence: 1.0
}

truth loan.changes_requested_reason {
  label: "Reason a staff reviewer gave when requesting changes"
  lifetime: system
  authority: { mode: human, ref: @actor.staff }
  visibility: [partner, staff, system]
  status: observed
  confidence: 0.95
  metadata: { note: "request_changes/2 stores the reason on loans.changes_requested_reason; the partner sees it on the draft (PartnerLive) and in a partner_notification." }
}

# --- Policies ---------------------------------------------------------
policy single_mutation_path on @loan.lifecycle {
  effect: require
  status: observed
  confidence: 0.95
  rule: "All loan state changes go through Kiva.Commands.execute/4, which re-runs role + required-input + eligibility gates and writes an audit event. The AI may only preview/3 and then execute a registered command."
}

policy partner_owns_draft on @loan.authoring {
  effect: require
  status: observed
  confidence: 0.95
  rule: "save_loan_draft / apply_reuse_suggestion / submit_loan_for_review require the acting user's managed_partner_id to match the draft's partner_id (Eligibility.partner_owns_draft)."
}

policy submit_requires_complete_draft on @loan.authoring {
  effect: require
  status: observed
  confidence: 0.95
  rule: "submit_loan_for_review gates on draft_complete (borrower, sector, amount>0, term, source title/story/use present) and required_lc_source_exists."
}

policy listing_approval_gates on @loan.review {
  effect: require
  status: observed
  confidence: 0.95
  rule: "approve_loan_listing requires translations_ready_or_fallback_allowed (always :ok in demo), risk_summary_present, and partner_review_complete (status in submitted_to_staff | staff_review)."
}

policy public_visibility on @loan.fund {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "Only loans whose status is in fundraising | funded | funded_disbursed | repaying | completed appear in the public localized search/profile."
}

constraint constraint.repay.one_schedule_per_loan {
  constraintType: data
  statement: "A loan has at most one repayment schedule, enforced by a unique index on repayment_schedules.loan_id."
  appliesTo: [@loan.repay, @repayment_schedule.item_terms]
  consequence: ["A second schedule would double what the borrower appears to owe and what lenders are shown as coming back, since both the portfolio projections and the partner's due list sum the items", "An attempted duplicate raises rather than being silently written"]
  verification: ["priv/repo/migrations/20260812175557_add_unique_repayment_schedule_per_loan.exs, applied against 98,141 existing schedules with no duplicates to clean up first", "'the database refuses a loan a second repayment schedule' (test/kiva/runtime_repayment_test.exs)"]
  knowledge: {
    scope: ["every repayment schedule"]
    evidence: [@evidence.repay.schedule_call_sites]
    owner: "Paul Ericksen"
    learnedAt: "2026-08-12"
  }
  status: observed
  confidence: 1.0
  metadata: {
    note: "Loan declared has_one :repayment_schedule from the start, but the database allowed several. The disbursal and funding paths hold the loan row FOR UPDATE across their check-then-insert, so a duplicate was already unreachable through them; the index makes that structural instead of dependent on every future caller remembering the lock."
  }
}

obligation obligation.repay.disbursal_produces_a_schedule on @loan.repay {
  label: "A disbursed loan owes a repayment schedule"
  trigger: "A loan's funds reach the borrower — Kiva.Lending.record_disbursal/1, whether run by a partner, by staff, or by advance_demo_time"
  requirement: "The loan must end that step with a repayment schedule and its items, because from that moment a borrower owes repayments, lenders are shown expected repayments, and the portfolio projections read from those rows."
  completion: "Kiva.Lending.record_disbursal/1 and the funding-completion paths (Portfolio.lend/4, simulate_funding/1) each run inside a transaction holding the loan row FOR UPDATE, and call ensure_repayment_schedule/1 within it. That function is idempotent — a seeded loan keeps the schedule it already has — and otherwise builds one via create_principal_repayment_schedule/4, which writes the schedule and every item together or not at all, and cannot write a second one — @constraint.repay.one_schedule_per_loan. Held by test/kiva/runtime_repayment_test.exs — eleven cases, every one proven to fail with the code, guard, or constraint it covers removed."
  rationale: "Every loan in the demo has a schedule because the seeds give it one, which is exactly why the gap was invisible: it only appeared on a loan that lived its whole life at runtime."
  status: observed
  confidence: 1.0
}

finding finding.repay.runtime_loans_never_repay {
  label: "A loan born and disbursed at runtime stalls forever, silently"
  derivedFrom: [@evidence.repay.schedule_call_sites]
  claim: "A loan that goes through its whole life at runtime — submitted, approved, funded, disbursed — never acquires a repayment schedule, and therefore never repays. record_repayment/1 refuses it with {:error, :no_schedule}. advance_demo_time/0 does not even reach that refusal: advance_one/1 tests next_scheduled?(loan), which answers false for a loan with no schedule, so the loan falls through to :none and the tick reports nothing happening. The loan sits in repaying-eligible status permanently, its lenders keep an expected repayment that will never arrive, and no error is raised, logged, or revealed to anyone."
  limitations: ["Not reproduced end-to-end in a test; established by reading every call site of create_repayment_schedule/4 and the advance_one/1 cond", "Invisible in the seeded dataset, where every loan is given a schedule at seed time"]
  invalidatedWhen: "record_disbursal/1 creates the schedule, or another runtime path does, and a test drives submit → approve → fund → disburse → repay to completion without touching a fixture"
  status: retired
  confidence: 1.0
  metadata: { retired: "2026-08-12, by @decision.repay.disbursal_owns_the_schedule — the invalidation condition above was met in the same session the finding was written. Kept rather than deleted because the shape of the miss is worth remembering: two seeded fixtures made a whole runtime path look exercised." }
}

decision_record decision.repay.disbursal_owns_the_schedule {
  label: "Disbursal creates the repayment schedule, and it totals exactly the principal"
  status: observed
  confidence: 1.0
  summary: "WHERE: the schedule is created at disbursal rather than at approval or first repayment, because disbursal is the moment the borrower actually owes anything — and, for a loan disbursed while the crowd was still lending, again on the last dollar, since a loan disbursed before this rule existed has no schedule for disbursal to have created. Its due dates are anchored to disbursed_at, not to the day the schedule was written. HOW MUCH: the items total exactly the loan principal, spreading the division remainder one cent at a time across the earliest months — the flat per-month figure the seeds use can total more or less than the loan, which is the accidental over-scheduling @question.lending.model_partner_interest is about. That question stays open: choosing exact principal for runtime loans does not decide whether the demo should model partner interest deliberately, and it changes nothing about seeded data. WHAT STATUS: only a fundraising or funded loan enters repayment, and only once it is fully funded AND holds a schedule. A partner disbursing early leaves the loan fundraising so the remaining lenders can still reach it; a loan whose term is missing stays funded rather than claiming a repayment it cannot make; and a completed or defaulted loan neither changes status nor receives fresh obligations from a repeated disbursal. Disbursal itself is idempotent — a repeat call keeps the original date and status and tells no one a second time. Three of these five rules exist only because adversarial review of the first draft found each of them missing."
}

evidence evidence.repay.schedule_call_sites {
  kind: observation
  occurredAt: "2026-08-12"
  subject: @loan.repay
  method: "Grepped every reference to create_repayment_schedule/4, RepaymentSchedule, and RepaymentScheduleItem across lib/, priv/, and test/; read record_disbursal/1, record_repayment/1, advance_one/1, and next_scheduled?/1."
  observation: "create_repayment_schedule/4 has four callers: priv/repo/seeds_loans.exs:221, priv/repo/seeds.exs:700, test/support/lending_fixtures.ex:118, test/kiva/partner_ops_test.exs:73. None is in lib/. Nothing in the runtime lifecycle constructs a RepaymentSchedule. record_repayment/1 opens by returning {:error, :no_schedule} when the preload comes back nil, and next_scheduled?/1 has a catch-all clause returning false for the same case."
  provenance: { doc: "session 2026-08-12, node-kind coverage pass" }
  scope: ["lib/kiva/lending.ex"]
  status: observed
  confidence: 1.0
}

policy repayment_actor_restricted on @loan.repay {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "record_repayment is invokable only by partner | staff | admin (the partner remits what the borrower repaid); the UI button on the loan profile is shown only to those roles."
}

# --- Flows ------------------------------------------------------------
flow loan.application_to_listing {
  label: "Draft -> submitted -> review -> approved/fundraising"
  status: observed
  confidence: 0.95
  entry: draft
  terminal: fundraising

  state draft
  state submitted_to_staff
  state staff_review
  state changes_requested
  state fundraising

  step author_draft {
    actor: @actor.partner
    writes: [@loan.amount_cents, @loan.story_text, @loan.risk_summary_public]
  }

  step submit_for_review {
    actor: @actor.partner
    reads: [@loan.story_text]
    writes: [@loan.status, @loan.risk_summary_public]
  }

  step staff_request_changes {
    actor: @actor.staff
    writes: [@loan.status]
  }

  step approve_listing {
    actor: @actor.staff
    reads: [@loan.risk_summary_public]
    writes: [@loan.status]
  }

  transition draft -> draft on save_loan_draft do [author_draft]
  transition draft -> submitted_to_staff on submit_loan_for_review do [submit_for_review]
  transition submitted_to_staff -> staff_review on staff_opens_review
  transition submitted_to_staff -> changes_requested on request_loan_changes do [staff_request_changes]
  transition staff_review -> changes_requested on request_loan_changes do [staff_request_changes]
  transition changes_requested -> submitted_to_staff on submit_loan_for_review
  transition submitted_to_staff -> fundraising on approve_loan_listing do [approve_listing]
  transition staff_review -> fundraising on approve_loan_listing do [approve_listing]
}

flow loan.fund_to_completion {
  label: "Fundraising -> funded -> (disbursed) -> repaying -> completed"
  status: observed
  confidence: 0.95
  entry: fundraising
  terminal: completed

  state fundraising
  state funded
  state funded_disbursed
  state repaying
  state completed

  step lend {
    actor: @actor.lender
    reads: [@loan.amount_cents, @loan.funded_amount_cents]
    writes: [@loan.funded_amount_cents, @loan.status]
  }

  step record_disbursal {
    actor: @actor.partner
    reads: [@loan.amount_cents, @loan.funded_amount_cents]
    writes: [@loan.disbursal_status, @loan.status, @repayment_schedule.item_terms, @repayment_schedule.item_status]
  }

  step record_repayment {
    actor: @actor.partner
    reads: [@repayment_schedule.item_status]
    writes: [@repayment_schedule.item_status, @loan.status, @repayment.lender_principal_returned_cents]
  }

  transition fundraising -> fundraising on complete_demo_lend do [lend]
  transition fundraising -> funded on complete_demo_lend do [lend]
  transition fundraising -> fundraising on early_disbursal do [record_disbursal]
  transition fundraising -> repaying on funding_completes_after_disbursal do [lend]
  transition funded -> repaying on record_disbursal do [record_disbursal]
  transition funded -> completed on record_repayment do [record_repayment]
  transition repaying -> repaying on record_repayment do [record_repayment]
  transition repaying -> completed on last_item_paid do [record_repayment]
}

# --- 2026-08-10: first-person layer — lender and partner journeys ------
# Seeded from docs/storytime/dashboard_first_person_audit_2026-08-10.md.
# Both journeys are practitioner_unvalidated: the audit's rendered cold-reads
# are agent_walked evidence, not a Practitioner Reality Gate.

story story.lender.portfolio_checkin for @actor.lender {
  label: "Morgan returns: what has my money done — and put it back to work"
  servesOutcome: @outcome.lender.principal_back_to_relend
  practitionerGate: practitioner_unvalidated
  evidenceLevel: agent_walked
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
  summary: "/portfolio is the house Law-23 exemplar — the hero already answers the top of the stack. This journey keeps it and closes the two gaps: the risk question (losses summed nowhere, audit M2) and findability (no text search across 1,408, audit M3)."
  screenplay: {
    id: "SPL-portfolio-habitual"
    mindset_variant: habitual
    register: "@actor.lender lexicon — second person, plain en, no industry jargon"
    beats: [
      { stage: @stage.portfolio.arrival, screen_says: "You've lent %{total_lent} across %{loan_count} loans — %{returned} has come back, and %{available} is ready to lend again.", actor_thinks: "Good — it's moving. Anything gone wrong?", actor_does: "Glances at the risk line under the ring.", screen_replies: "%{behind} behind schedule · %{lost} lost across %{lost_count} loans — see the breakdown.", forces_truths: [@loan.loss_attribution, @repayment.arrears_aging] },
      { stage: @stage.portfolio.arrival, screen_says: "(relend banner) %{available} is ready to lend again.", actor_thinks: "Put it back to work.", actor_does: "Says: 'Lend it again — same countries as before.'", screen_replies: "Preview: %{count} matching loans, %{amount} each. Confirm?", forces_truths: [] },
      { stage: @stage.portfolio.risk_opaque, screen_says: "(today) 66% repaid ring; a small behind-schedule badge; losses summed nowhere.", actor_thinks: "Did I actually lose money? I can't tell from here.", actor_does: "Leaves without relending.", screen_replies: "(nothing — the bail is silent)", forces_truths: [@loan.loss_attribution] }
    ]
    transcribed_keys: []
    note: "Stub (v1.12): beats seed the risk-line + relend rework. Lines are transcription CANDIDATES, not shipped copy — the string catalog takes them with per-key provenance when the surfaces are built (L82)."
  }
}

stage stage.portfolio.arrival in @story.lender.portfolio_checkin {
  label: "Portfolio open — the money answers first"
  interiorMonologue: {
    habitual: ["What has my money done since I was here last?", "Anything gone wrong I should know about?", "There's money sitting here — put it back to work."]
    returning_after_away: ["How much came back while I was away? Am I still on track?"]
    something_wrong: ["Behind schedule — how bad is it, and did I actually lose anything?"]
  }
  monologueProvenance: "Drafted (model-derived from the audit cold-read); no practitioner verbatims yet"
  questionStack: [
    { q: "What has my money done?", answeredBy: [@repayment.lender_principal_returned_cents, @portfolio.impact], today: "answered — hero ring/stats; keep it (audit: the house Law-23 exemplar)" },
    { q: "Is any of it in trouble?", answeredBy: [@repayment.arrears_aging, @loan.loss_attribution], today: "partial — behind-schedule badge only; losses summed nowhere (audit M2)" },
    { q: "What can I do right now?", answeredBy: [@decision.portfolio.relend], today: "answered — the relend banner is the page's one action" },
    { q: "Did I lend to this person? (find a specific loan)", answeredBy: [@ask.portfolio.find_loan], today: "unanswered — facets only, no text search across 1,408 (audit M3)" }
  ]
  actorCanKnow: ["Totals lent and returned", "Available-to-relend amount", "Which loans sit behind schedule"]
  actorCannotKnowYet: ["Final outcome of active loans", "Summed losses (truth not derived yet)"]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.85
}

decision decision.portfolio.relend at @stage.portfolio.arrival {
  label: "Put returned money back to work"
  resolvesTo: [@complete_demo_lend]
  exposure: primary
  status: observed
  confidence: 0.9
}

decision decision.portfolio.inspect_risk at @stage.portfolio.arrival {
  label: "See what is behind schedule and what was lost"
  resolvesTo: [@ask.portfolio.risk_breakdown]
  exposure: secondary
  status: asserted
  confidence: 0.85
  metadata: { blockedToday: "No risk-details surface exists; ruled and pending (@decision.lender_risk_details_page)" }
}

decision decision.portfolio.find_loan at @stage.portfolio.arrival {
  label: "Find a specific loan or borrower by name"
  resolvesTo: [@ask.portfolio.find_loan]
  exposure: secondary
  status: asserted
  confidence: 0.85
}

stage stage.portfolio.risk_opaque in @story.lender.portfolio_checkin {
  label: "Bail path: the trust question goes unanswered"
  summary: "Morgan wonders whether she lost money; no surface sums losses, so she leaves without relending. The bail is silent — the cost of audit finding M2."
  interiorMonologue: {
    something_wrong: ["Did I actually lose anything? I can't tell from here — never mind."]
  }
  questionStack: [
    { q: "Did I actually lose money, and how much?", answeredBy: [@loan.loss_attribution], today: "unanswerable on any surface; via Ask Mode only in principle, and chat is dark (audit H1)" }
  ]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.8
}

decision decision.portfolio.ask_risk at @stage.portfolio.risk_opaque {
  label: "Ask the risk question anyway"
  resolvesTo: [@ask.portfolio.risk_breakdown]
  exposure: contextual
  status: asserted
  confidence: 0.8
  metadata: { note: "A top-of-stack question answerable only via Ask Mode is itself a Law-23 finding — the surface made the actor ask." }
}

ask ask.portfolio.find_loan {
  label: "Did I lend to this person? (text search across my lendings)"
  visibility: [lender]
  provenance: "Derived over the lender's lendings joined to localized loan/borrower names — no implementation yet (audit M3)"
  status: asserted
  confidence: 0.85
}

ask ask.portfolio.risk_breakdown {
  label: "What is behind schedule, what was lost, where?"
  visibility: [lender]
  provenance: "Per-loan loss attribution + arrears aging sliced by country and partner — truths @loan.loss_attribution / @repayment.arrears_aging pending (@decision.lender_risk_details_page)"
  status: asserted
  confidence: 0.85
}

intent intent.portfolio.relend_repayments for @actor.lender {
  label: "Lend what came back again"
  mode: command
  phrasings: [
    "Lend my returned money again"
    "Put my money back to work"
    "Lend $50 to weaving"
  ]
  resolvesTo: [@complete_demo_lend]
  requiresTruths: [@repayment.lender_principal_returned_cents]
  servesOutcome: @outcome.lender.principal_back_to_relend
  availableAt: [@stage.portfolio.arrival]
  maturity: implemented
  status: observed
  confidence: 0.85
}

intent intent.portfolio.risk_question for @actor.lender {
  label: "Is my money safe — did I lose anything?"
  mode: ask
  phrasings: [
    "Did I lose any money?"
    "How much is behind schedule?"
  ]
  resolvesTo: [@ask.portfolio.risk_breakdown]
  servesOutcome: @outcome.lender.principal_back_to_relend
  availableAt: [@stage.portfolio.arrival, @stage.portfolio.risk_opaque]
  maturity: candidate
  status: asserted
  confidence: 0.8
}

story story.partner.morning_operations for @actor.partner {
  label: "Ana's morning: collect today, handle what review returned, watch expiring campaigns"
  servesOutcome: @outcome.partner.day_collected
  practitionerGate: practitioner_unvalidated
  evidenceLevel: agent_walked
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
  summary: "The audited workspace is inverted: the application factory leads while the operational morning trails or is absent (audit H5). This journey is the corrective spine — today's collections first, bounced submissions second, expiring campaigns third, the factory grid last."
  screenplay: {
    id: "SPL-partner-habitual"
    mindset_variant: habitual
    register: "@actor.partner lexicon — usted, professional es"
    beats: [
      { stage: @stage.partner.morning_checkin, screen_says: "Hoy: %{count} cobros por %{amount}. %{overdue_count} llevan más de %{days} días vencidos.", actor_thinks: "Primero lo de hoy.", actor_does: "Dice: 'Registrar los cobros de hoy.'", screen_replies: "Vista previa: %{count} cobros de hoy por %{amount}. ¿Confirmar el lote?", forces_truths: [@repayment_schedule.item_terms, @repayment.arrears_aging] },
      { stage: @stage.partner.morning_checkin, screen_says: "Revisión le devolvió %{count}: María — máquina de coser · $500 · falta la foto.", actor_thinks: "Eso primero — lo demás espera.", actor_does: "Abre la solicitud devuelta.", screen_replies: "(la solicitud abre con el motivo del revisor arriba)", forces_truths: [] },
      { stage: @stage.partner.morning_checkin, screen_says: "%{count} campañas vencen esta semana con menos del %{pct}% financiado.", actor_thinks: "¿Y qué puedo hacer con esas?", actor_does: "Pregunta qué opciones tiene.", screen_replies: "(open — no rescue action is registered; @question.partner.expiring_rescue)", forces_truths: [@loan.fundraising_ends_at] },
      { stage: @stage.partner.bounced_wall, screen_says: "(today) #3000003 · draft · Continue — rows with no name, title, date, or amount.", actor_thinks: "Esta lista no me dice cuál es cuál.", actor_does: "Abre borradores al azar buscando la devuelta.", screen_replies: "(each opens blind — the failure this journey retires; audit H3)", forces_truths: [] }
    ]
    transcribed_keys: []
    note: "Stub (v1.12). es-source lines are candidates for the per-locale catalog; the drafts-row identity sentence derives from @loan.story_text recognized_by."
  }
}

stage stage.partner.morning_checkin in @story.partner.morning_operations {
  label: "Workspace open — ¿qué cobro hoy?"
  interiorMonologue: {
    habitual: ["¿Qué cobro hoy?", "¿Qué me devolvió el equipo de revisión?", "¿Qué campaña está por vencer?"]
    first_time: ["¿Dónde está lo de hoy? Esto me muestra formularios, no mi día."]
    something_wrong: ["Esta lista no me dice cuál es cuál — ¿la #3000003 es la de María o la de Rosa?"]
  }
  monologueProvenance: "habitual lines are the audit's derived seeds (verbatim from the audit doc, still model-authored); no practitioner verbatims yet"
  questionStack: [
    { q: "What must I collect today — how many, how much?", answeredBy: [@ask.partner.due_today, @repayment_schedule.item_terms], today: "stat #4 + a Manage link only (audit H5)" },
    { q: "What came back from staff review, and why?", answeredBy: [@loan.status, @loan.changes_requested_reason], today: "buried undifferentiated in the drafts wall, labeled by raw id (audit H3)" },
    { q: "What is about to expire underfunded?", answeredBy: [@loan.fundraising_ends_at, @loan.funded_amount_cents], today: "no surface at all (audit H5)" },
    { q: "Start or continue an application", answeredBy: [@decision.partner.continue_application], today: "answered — currently the PRIMARY surface, which is the inversion" }
  ]
  actorCanKnow: ["Today's due collections", "Which submissions bounced and the reviewer's reason", "Campaign deadlines and funding levels"]
  actorCannotKnowYet: ["Whether staff will approve pending submissions"]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.85
}

decision decision.partner.record_todays_collections at @stage.partner.morning_checkin {
  label: "Record today's collections"
  resolvesTo: [@record_repayment]
  exposure: primary
  status: observed
  confidence: 0.9
  metadata: { note: "Today this resolves per-loan; the ruled day-batch flow (preview -> confirm through the registry) is mandated by @decision.partner_bulk_collections / @product.bulk_collections (product ledger); per-loan stays as the exception path." }
}

decision decision.partner.review_expiring at @stage.partner.morning_checkin {
  label: "See which campaigns are about to expire underfunded"
  resolvesTo: [@ask.partner.expiring_campaigns]
  exposure: secondary
  status: asserted
  confidence: 0.8
}

decision decision.partner.continue_application at @stage.partner.morning_checkin {
  label: "Start or continue a loan application"
  resolvesTo: [@start_loan_application]
  exposure: secondary
  status: observed
  confidence: 0.9
  metadata: { note: "Demoted from primary in the reworked workspace: the factory grid moves second to the operational morning (audit H5)." }
}

stage stage.partner.bounced_wall in @story.partner.morning_operations {
  label: "Failure path: review bounced a submission and Ana cannot find it"
  summary: "changes_requested drafts mix undifferentiated into the pile as '#3000003 · draft · Continue' — no borrower name, title, date, or amount (audit H3). The identity Ana recognizes is declared recognized_by on @loan.story_text; the reviewer's reason (@loan.changes_requested_reason) exists and must lead the row."
  interiorMonologue: {
    something_wrong: ["Revisión me devolvió algo — ¿cuál de todos es? ¿Y qué le faltó?"]
  }
  questionStack: [
    { q: "Which application bounced, and what did the reviewer want changed?", answeredBy: [@loan.changes_requested_reason], today: "the reason exists once the draft is found; finding it is the failure" }
  ]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.85
}

decision decision.partner.address_changes at @stage.partner.bounced_wall {
  label: "Fix what review asked and resubmit"
  resolvesTo: [@save_loan_draft, @submit_loan_for_review]
  exposure: primary
  status: observed
  confidence: 0.9
}

ask ask.partner.due_today {
  label: "What do I collect today — how many repayments, how much money?"
  visibility: [partner, staff]
  provenance: "Aggregate over repayment schedule items due today for the partner's loans (@repayment_schedule.item_terms); the count exists as workspace stat #4, the answering strip does not (audit H5)"
  status: asserted
  confidence: 0.85
}

ask ask.partner.expiring_campaigns {
  label: "Which of my campaigns end soon while underfunded?"
  visibility: [partner, staff]
  provenance: "@loan.fundraising_ends_at vs today joined to funded percent — truth exists in schema, no surface (audit H5)"
  status: asserted
  confidence: 0.85
}

intent intent.partner.collect_today for @actor.partner {
  label: "Registrar los cobros de hoy"
  mode: command
  phrasings: [
    "Registrar los cobros de hoy"
    "Record today's collections"
    "¿Qué cobro hoy?"
  ]
  resolvesTo: [@record_repayment]
  requiresTruths: [@repayment_schedule.item_terms]
  clarifiesWith: [@ask.partner.due_today]
  servesOutcome: @outcome.partner.day_collected
  availableAt: [@stage.partner.morning_checkin]
  maturity: candidate
  status: asserted
  confidence: 0.8
}

question question.partner.expiring_rescue on @decision.partner.review_expiring {
  questionType: open_question
  ask: "What can a partner DO about an expiring underfunded campaign — extend the deadline, boost visibility, withdraw? No rescue command is registered and no policy exists."
  whyItMatters: "The expiring-campaigns surface (audit H5) can show the problem but offers no legal decision; a stage with a visible worry and no affordance violates StoryTime Law 2."
  owner: "Paul Ericksen"
  neededBy: "The partner 'Today' workspace rework"
  blocking: ["The action column of the expiring-campaigns block"]
  resolveWith: ["Product ruling on the legal rescue action(s); then a registered command + eligibility"]
  knowledge: {
    scope: ["Partner workspace expiring-campaigns block"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-08-10"
    invalidatedBy: ["A rescue command is ruled and registered, or expiry handling is ruled out of partner hands"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}

# --- 2026-08-10: product rulings owned by this subsystem ----------------
# Restructured from the product contract's audit-rulings section (grammar
# upgrade); ruling content preserved. Implementation state lives on the
# mandated initiatives in the product ledger, not on these records.

decision_record decision.partner_bulk_collections {
  decision: "Partner repayment recording is a bulk day-batch flow: 'record today's collections' — a day-batch selection with preview -> confirm through Kiva.Commands — not per-loan single clicks (1,992 due x 80 pages at current scale). Rows carry the decision's truths: due date, amount, overdue aging. Per-loan recording remains available as the exception path."
  state: active
  authority: { mode: human, owner: "Paul Ericksen" }
  decidedAt: "2026-08-10"
  basedOn: [@dashboard_first_person_audit]
  alternatives: ["Keep per-loan single-click recording only", "Auto-record on due date without partner confirmation"]
  consequences: ["A day-batch selection + bulk preview/confirm path must be designed through the command registry", "Collections rows must reveal @repayment_schedule.item_terms and @repayment.arrears_aging"]
  revisitWhen: ["Collections stop being a daily batch reality for partners", "Scale changes make per-loan ceremony viable again"]
  supersedes: []
  mandates: [@product.bulk_collections]
  status: confirmed
  confidence: 1.0
  metadata: { ruling: "owner, 2026-08-10 ('do bulk collections'); audit Q2" }
}

decision_record decision.lender_risk_details_page {
  decision: "Lender risk honesty lives on a dedicated details page: the portfolio hero keeps its warm impact framing; a separate risk & repayment details surface breaks down currency/exchange loss, defaults, and amounts in arrears, sliced by country and partner. The portfolio hero links to it."
  state: active
  authority: { mode: human, owner: "Paul Ericksen" }
  decidedAt: "2026-08-10"
  basedOn: [@dashboard_first_person_audit]
  alternatives: ["Put full risk detail on the portfolio hero itself", "Leave risk at the behind-schedule badge"]
  consequences: ["Forces derived truths that do not exist yet: @loan.loss_attribution (principal lost to default) and @repayment.arrears_aging buckets", "Currency/exchange loss is currently OUT OF MODEL — all lendings are USD (@constraint.portfolio.usd_only_no_fx); the page needs either a modeled FX truth or an explicit exclusion note (@question.portfolio.fx_modeling)", "The hero gains one honest risk line linking here (audit rethink)"]
  revisitWhen: ["Multi-currency lending enters the model", "The hero's warm framing is re-ruled"]
  supersedes: []
  mandates: [@product.risk_details_page]
  status: confirmed
  confidence: 1.0
  metadata: { ruling: "owner, 2026-08-10; audit Q3" }
}

constraint constraint.portfolio.usd_only_no_fx {
  constraintType: data
  statement: "All lendings and loan amounts are USD cents; currency/exchange loss does not exist in the model — there is no FX truth to derive or sum."
  appliesTo: [@loan.fund, @portfolio.impact]
  consequence: ["The risk-details surface must either carry an explicit 'no currency loss — all lending is in USD' exclusion note or wait for a modeled FX-loss truth (@question.portfolio.fx_modeling)"]
  verification: ["Schema carries cents-only amounts with no currency column (2026-08-10 audit code read)"]
  knowledge: {
    scope: ["kredo demo lending model as of 2026-08-10"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-08-10"
    invalidatedBy: ["A currency column / FX modeling lands"]
    supersedes: []
  }
  status: asserted
  confidence: 0.9
}

question question.portfolio.fx_modeling on @constraint.portfolio.usd_only_no_fx {
  questionType: open_question
  ask: "Model currency/exchange loss as a real truth (multi-currency demo data), or ship the risk-details page with an explicit all-USD exclusion note?"
  whyItMatters: "The risk-details ruling names FX loss as one of its three breakdowns; today it cannot be non-zero, and an unexplained $0 line would read as a claim."
  owner: "Paul Ericksen"
  neededBy: "Risk-details page build (@product.risk_details_page)"
  blocking: ["The FX line of the risk-details surface"]
  resolveWith: ["Product decision; if modeled — a currency truth + generator support; if excluded — the exclusion sentence becomes a transcribed catalog string"]
  knowledge: {
    scope: ["Lender risk-details surface"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-08-10"
    invalidatedBy: ["Either resolution ships"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}

# --- Views ------------------------------------------------------------
view partner_workspace for @outcome.partner.loan_listed {
  label: "Partner chat-assisted loan application workspace (PartnerLive)"
  status: observed
  confidence: 0.95
  affordances: [list, form, card, alert, submit]
  reveals: [@loan.status, @loan.amount_cents, @loan.story_text, @loan.risk_summary_public]
  commands: [start_loan_application, save_loan_draft, apply_reuse_suggestion, submit_loan_for_review]
}

view admin_review_queue for @story.staff.decision_sweep {
  label: "Staff loan review queue with expandable review detail (AdminLive)"
  status: observed
  confidence: 0.95
  affordances: [card, table, button, expandable_detail, missing_fields_warning]
  reveals: [@loan.status, @loan.risk_summary_public, @loan.story_text]
  commands: [approve_loan_listing, request_loan_changes]
  metadata: {
    detail: "Kiva.Lending.review_detail/2 — each card expands to localized story / loan_use / risk / repayment summary, per-locale translation coverage (locale:status, source flag), and a computed missing-fields list (story|risk|loan_use|repayment_term). Staff approve with eyes open, not blind."
  }
}

view loan_index for @loan.fund {
  label: "Public localized loan browse with filters (LoanLive.Index)"
  status: observed
  confidence: 0.95
  affordances: [list, filter, card, lend_cta]
  reveals: [@loan.status, @loan.amount_cents, @loan.funded_amount_cents, @loan.story_text]
  commands: []
  metadata: { note: "Each loan_card is a link to the profile and shows a visible 'Lend ->' affordance so the action is discoverable to anonymous visitors." }
}

view loan_show for @loan.fund_to_completion {
  label: "Localized loan profile: fund, encourage, repayment schedule (LoanLive.Show)"
  status: observed
  confidence: 0.95
  affordances: [card, form, confirm, progress, table, alert, badge, signin_to_lend_cta]
  reveals: [@loan.status, @loan.funded_amount_cents, @loan.disbursal_status, @loan.risk_summary_public, @repayment_schedule.item_status]
  commands: [add_loan_to_basket, complete_demo_lend, record_repayment, submit_encouragement_message]
  metadata: { lend_affordance: "the lend form renders only for role == lender; anonymous / non-lender viewers see a 'Sign in as a lender to lend' CTA linking to /login (with demo quick-fill), so lending is never a dead end." }
}

view partner_dashboard for @story.partner.morning_operations {
  label: "Partner portfolio: active loans, total raised, repayments-due list (PartnerLive)"
  status: observed
  confidence: 0.95
  affordances: [stats, list, link, button]
  reveals: [@loan.status, @loan.funded_amount_cents, @repayment_schedule.item_status, @loan.disbursal_status]
  commands: [record_repayment, record_disbursal, create_borrower, start_loan_application]
}

view portfolio_impact for @story.lender.portfolio_checkin {
  label: "Lender impact dashboard: hero + repaid ring, cumulative repayment chart, slice-and-dice, loans touched (PortfolioLive)"
  status: observed
  confidence: 0.95
  affordances: [stats, hero, ring, chart, chart_table_twin, filter, group_by, drill_down, facet_cards, card, progress, list, relend_cta]
  reveals: [@repayment.lender_principal_returned_cents, @repayment_schedule.item_status, @loan.status]
  commands: []
  metadata: {
    source: "lib/kiva_web/live/portfolio_live.ex",
    since: "commit 60e21c8 (2026-07-07)",
    chart: "Money coming back — cumulative scheduled (dashed estimate) vs received (solid) lender-share over repaying/delinquent loans, both bucketed by installment due month so the past gap equals the behind-schedule amount; today marker, per-month tooltips, table twin, next-30-days and behind-schedule chips",
    slice_and_dice: "Filter by status/country/sector/partner (:direct for partnerless), group-by rollups ordered by lent desc (repaid tie-break) with drill-down, removable chips, slice totals; state is URL-backed via handle_params/push_patch",
    data: "Kiva.Portfolio: expected_repayment_series, late_and_upcoming, impact_groups, filtered_totals, filter_facets, filtered impact_loans"
  }
}

# --- Commands (registry + observed handlers) --------------------------
command create_borrower {
  label: "Partner onboards a new borrower (canonical + source LC + optional photo)"
  servesOutcome: @outcome.partner.loan_listed
  eligibility: ["Actor role partner"]
  effects: ["Borrower + source-locale content created; photo surfaced on cards/profiles"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["partner"], handler: "Kiva.Borrowers.create_borrower/2" }
}

command start_loan_application {
  label: "Create or resume a partner's open draft loan"
  servesOutcome: @outcome.partner.loan_listed
  eligibility: ["Actor role partner"]
  effects: ["Create the partner's draft, or resume the open one"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["partner"], side_effects: ["create_or_resume_draft"], handler: "Kiva.LoanApplications.create_or_resume_draft/2" }
}

command save_loan_draft {
  label: "Update a draft's canonical fields + source-locale content"
  servesOutcome: @outcome.partner.loan_listed
  eligibility: ["Actor role partner", "partner_owns_draft (@eligibility.partner_owns_draft)"]
  effects: ["Draft canonical fields + source-locale content updated"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["partner"], handler: "Kiva.LoanApplications.update_draft/3" }
}

command apply_reuse_suggestion {
  label: "Apply one reuse suggestion (sector/activity/country/trust_model) to a draft"
  servesOutcome: @outcome.partner.loan_listed
  eligibility: ["Actor role partner", "partner_owns_draft (@eligibility.partner_owns_draft)"]
  effects: ["Suggested field applied to the draft"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["partner"], handler: "Kiva.LoanApplications.apply_suggestion/3" }
}

command submit_loan_for_review {
  label: "Submit a complete draft for staff review (queues translations + risk backfill)"
  servesOutcome: @outcome.partner.loan_listed
  eligibility: ["draft_complete (@eligibility.draft_complete)", "partner_owns_draft (@eligibility.partner_owns_draft)", "required_lc_source_exists"]
  effects: ["Status -> submitted_to_staff", "Translation jobs queued", "Risk summary backfilled if blank"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["partner"], handler: "Kiva.LoanApplications.submit_for_review/1" }
}

command request_loan_changes {
  label: "Staff sends a loan back for changes (status -> changes_requested)"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["Actor role staff | admin"]
  effects: ["Status -> changes_requested with the reviewer's reason captured (@loan.changes_requested_reason)", "Partner notified (changes_requested reveal)"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["staff", "admin"], handler: "Kiva.Lending.request_changes/2", reveal: "notify_partner(changes_requested)" }
}

command approve_loan_listing {
  label: "Staff approves + publishes a loan (status -> fundraising)"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["translations_ready_or_fallback_allowed", "risk_summary_present (@eligibility.risk_summary_present)", "partner_review_complete (@eligibility.partner_review_complete)"]
  effects: ["Status -> fundraising (public listing)", "Partner notified (loan_approved reveal)"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["staff", "admin"], handler: "Kiva.Lending.approve_listing/1" }
}

command complete_demo_lend {
  label: "Lender funds a loan; crossing the goal flips status -> funded"
  servesOutcome: @outcome.lender.principal_back_to_relend
  eligibility: ["Actor role lender", "Loan status fundraising (@constraint.lending.fundraising_only_lending)", "$25-multiple amount (@constraint.lending.amount_is_25_multiple)"]
  effects: ["Lending created; funded amount advances (clamped to goal)", "Goal crossing flips status -> funded and notifies every lender once", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["lender"], handler: "Kiva.Portfolio.lend/4", reveal: "notify_loan_lenders on fully-funded" }
}

command record_repayment {
  label: "Partner/staff remits the next scheduled repayment; last item -> completed"
  servesOutcome: @outcome.partner.day_collected
  eligibility: ["Actor role partner | staff | admin", "Loan has an unpaid scheduled item"]
  effects: ["Earliest due scheduled item -> paid (sets paid_on)", "Last item completes the loan", "Lender principal is repaid proportionally", "Lenders notified (repayment reveal)", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["partner", "staff", "admin"], handler: "Kiva.Lending.record_repayment/1", bulk_path: "Day-batch flow ruled but not built — @decision.partner_bulk_collections / @product.bulk_collections" }
}

command record_disbursal {
  label: "Partner/staff records that funds reached the borrower (advances disbursal_status)"
  servesOutcome: @outcome.partner.day_collected
  eligibility: ["Actor role partner | staff | admin"]
  effects: ["Disbursal status advances (orthogonal to loan.status); disbursed_at stamped", "Lenders notified", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["partner", "staff", "admin"], handler: "Kiva.Lending.record_disbursal/1", note: "advances the orthogonal disbursal_status field; does NOT change loan.status" }
}

command advance_demo_time {
  label: "Demo time-machine: advance every active loan one lifecycle step (admin-only)"
  servesOutcome: @outcome.lender.principal_back_to_relend
  eligibility: ["Actor role admin"]
  effects: ["Per loan: fund -> disburse -> repay -> complete, one step", "Fires loan_funded / disbursal / repayment reveals to lenders"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["admin"], handler: "Kiva.Lending.advance_demo_time/0", note: "Demo lever — it exists so the lender's money-coming-back loop visibly moves in demos." }
}

# --- Eligibility checks (observed) ------------------------------------
policy eligibility.draft_complete on @loan.authoring {
  effect: require
  status: observed
  confidence: 0.95
  rule: "LoanApplications.draft_complete?/1 — borrower_id, sector_id, loan_amount_cents>0, repayment_term_months, and source title/borrower_story/loan_use all present."
}

policy eligibility.partner_owns_draft on @loan.authoring {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Eligibility.partner_owns_draft — acting user's managed_partner_id must equal the draft loan's partner_id."
}

policy eligibility.risk_summary_present on @loan.review {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Eligibility.risk_summary_present — the source loans_lc row must have a non-blank risk_summary_public."
}

policy eligibility.partner_review_complete on @loan.review {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Eligibility.partner_review_complete — loan status must be submitted_to_staff or staff_review before listing approval."
}

# --- Asserted (declared but NOT built) --------------------------------
policy partner_resumes_changes_requested on @loan.authoring {
  effect: allow
  status: observed
  confidence: 0.95
  rule: "PartnerLive lists changes_requested loans with the staff reason and an 'Address changes' button (edit_draft) that reopens the loan for editing; the partner saves (save_loan_draft) and resubmits (submit_loan_for_review -> submitted_to_staff)."
}

# --- Durable knowledge (2026-07-26 grammar adoption) -------------------

evidence evidence.lending.invariants_enforcement {
  kind: observation
  occurredAt: "2026-07-07"
  subject: @loan.fund
  method: "Code read of the enforcement sites plus the spec-test suite written first and driven green the same day"
  value: { enforcement: ["Kiva.Money.validate_lend_amount on Lend and Loan changesets", "Kiva.Portfolio.lend/4 raises unless Loan.lendable?/1 (status fundraising)", "Command eligibility rejects basket adds for non-fundraising loans", "Kiva.Basket.checkout/1 lends live items and reports stale ones", "DB checks in priv/repo/migrations/20260707190000_enforce_lending_invariants.exs"] }
  provenance: { commit: "044f9b2", tests: ["test/kiva/lend_amount_test.exs", "test/kiva/lend_status_test.exs", "test/kiva_web/live/loan_lend_affordance_test.exs"], suite: "mix test 260/260 green 2026-07-07" }
  integrity: { verification: "Full suite green at commit time" }
  scope: ["kredo lending write paths as of commit 044f9b2"]
  status: observed
  confidence: 0.98
}

constraint constraint.lending.amount_is_25_multiple {
  constraintType: data
  statement: "Lend amounts and loan/funded amounts must be positive multiples of $25 (2500 cents); zero is allowed only where explicitly declared (loan amounts before funding)."
  appliesTo: [@loan.fund, @loan.amount_cents, @loan.funded_amount_cents]
  consequence: ["Non-multiple amounts are rejected at changeset validation and, defensively, by DB check constraints"]
  verification: ["test/kiva/lend_amount_test.exs"]
  knowledge: {
    scope: ["All lending and loan-amount writes"]
    evidence: [@evidence.lending.invariants_enforcement]
    owner: "Paul Ericksen"
    learnedAt: "2026-07-07"
    invalidatedBy: ["A product decision to allow arbitrary amounts", "Migration or Kiva.Money semantics change"]
    supersedes: []
  }
  status: confirmed
  confidence: 0.98
}

constraint constraint.lending.fundraising_only_lending {
  constraintType: operational
  statement: "New lending (direct lend, basket add, basket checkout) is accepted only while the loan status is fundraising; checkout skips and reports items whose loan has left fundraising."
  appliesTo: [@loan.fund, @loan.status]
  consequence: ["Funded/repaying/completed/delinquent/defaulted loans cannot receive new lending; affordances hide the lend form and drawer support button for them"]
  verification: ["test/kiva/lend_status_test.exs", "test/kiva_web/live/loan_lend_affordance_test.exs"]
  knowledge: {
    scope: ["All lending write paths and lend affordances"]
    evidence: [@evidence.lending.invariants_enforcement]
    owner: "Paul Ericksen"
    learnedAt: "2026-07-07"
    invalidatedBy: ["A product decision to allow secondary funding states"]
    supersedes: []
  }
  status: confirmed
  confidence: 0.98
}

evidence evidence.lending.schedule_spacing {
  kind: observation
  occurredAt: "2026-07-07"
  subject: @repayment_schedule.item_status
  method: "Direct query of generated schedule items during test debugging after a calendar-month assumption produced a wrong expected value"
  value: { example: "create_repayment_schedule(loan, ~D[2026-07-01], 8, 12500) yields due_on 2026-07-31, 08-30, 09-29, 10-29, 11-28, 12-28, 2027-01-27, 2027-02-26" }
  provenance: { file: "lib/kiva/lending.ex create_repayment_schedule", test: "test/kiva/portfolio_slice_test.exs late_and_upcoming block" }
  integrity: { verification: "Reproduced by the committed test, which derives expectations from actual due dates" }
  scope: ["Schedules generated by Kiva.Lending.create_repayment_schedule"]
  status: observed
  confidence: 1.0
}

counterexample counterexample.lending.calendar_month_schedules {
  proposition: "Repayment installments fall on calendar-month boundaries (the 1st, or a fixed day-of-month)."
  case: "Generated schedules space items exactly 30 days from starts_on, so due dates drift through the month across the term."
  conditions: ["Schedule created by Kiva.Lending.create_repayment_schedule (all seeded and fixture schedules)"]
  observation: "An 8-item schedule starting 2026-07-01 dues on the 31st, 30th, 29th, ... — never on the 1st."
  implications: ["Month-bucketing must go through date_trunc('month', due_on), not day-of-month math", "Tests must derive expectations from actual due dates rather than assuming month-firsts"]
  limitations: ["Says nothing about real-world partner remittance calendars; this is the demo generator's behavior"]
  knowledge: {
    scope: ["kredo demo repayment schedules"]
    evidence: [@evidence.lending.schedule_spacing]
    owner: "Paul Ericksen"
    learnedAt: "2026-07-07"
    invalidatedBy: ["create_repayment_schedule changes to calendar-month stepping"]
    supersedes: []
  }
  status: observed
  confidence: 1.0
}

question question.portfolio.received_bucketing on @portfolio_impact {
  questionType: open_question
  ask: "Should the repayment chart's received series bucket by paid_on (cash view) instead of due_on (schedule view)?"
  whyItMatters: "Due-on bucketing makes the past gap exactly the behind-schedule amount, but it hides late-payment timing; a cash view would show when money actually arrived and diverge from the behind-schedule chip."
  owner: "Paul Ericksen"
  neededBy: "Before the chart is reused for any real-money analytics surface"
  blocking: []
  resolveWith: ["Product decision; if changed, re-read expected_repayment_series and the chart card copy together so the gap narrative stays truthful"]
  knowledge: {
    scope: ["PortfolioLive Money-coming-back chart"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-07-07"
    invalidatedBy: ["The chart is removed or redesigned"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}
```
