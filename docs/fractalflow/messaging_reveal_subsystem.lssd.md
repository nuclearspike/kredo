<!--
Canonical-For: lib/kiva/messaging.ex, lib/kiva/moderation.ex, lib/kiva/notifications.ex, lib/kiva/updates.ex, lib/kiva_web/live/portal_live.ex, lib/kiva_web/live/notifications_live.ex
Status: ACTIVE
-->

# FractalFlow — Messaging, Moderation & Reveal Subsystem

Models the cross-language lender→borrower encouragement pipeline (moderate → persist source → machine-translate → reveal in the borrower's language) and the lender reveal layer (notifications generated when a loan funds or repays, surfaced via the nav bell and the `/notifications` feed). Asserted nodes mark rails that exist but are not yet built: partner-authored borrower updates and partner-routed notifications.

2026-08-10: grammar upgrade + the v1.12 first-person layer for the borrower
portal journey this subsystem owns (view @borrower_portal). Rosa's stage
records carry interior monologue and a ranked question stack seeded from
docs/storytime/dashboard_first_person_audit_2026-08-10.md; the journey is
explicitly `practitioner_unvalidated`. The sender-reveal product ruling
(audit Q1) lives here as a decision_record; the truth it forces
(user.profile_public) is filed backward into the identity contract.

```lssd
model kiva.messaging_reveal@0.2.0 {
  namespace: "kiva.messaging_reveal"
  revision: "2026-08-10"
  status: observed
  confidence: 0.9
}

module messaging.reveal {
  label: "Messaging, moderation and the lender reveal layer"
  contains: [@messaging.encouragement, @messaging.reveal_layer]
  status: observed
  confidence: 0.95
}

system messaging.encouragement {
  label: "Cross-language encouragement pipeline"
  contains: [@encouragement.write, @encouragement.read_native, @borrower_update.post]
  status: observed
  confidence: 0.95
  metadata: { impl: "Kiva.Messaging.create_encouragement/4" }
}

system messaging.reveal_layer {
  label: "Lender reveal layer (notifications)"
  contains: [@reveal.read_notifications]
  status: observed
  confidence: 0.95
  metadata: { impl: "Kiva.Notifications" }
}

# --- Outcomes (2026-08-10) ----------------------------------------------
outcome outcome.borrower.money_status_known {
  label: "The borrower opens her page and the money question is already answered — in her language"
  steps_max: 1
  vocabulary: actor
  summary: "Zero steps to the answer (state-dependent headline: fundraising -> percent + remaining + days left; repaying -> next payment + on-track), one step for her one action (post an update / thank a supporter). Depends on the locale-precedence fix (@finding.localization.locale_precedence_defeats_default) and on suppressing repayment scaffolding for fundraising loans (audit M1)."
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
}

outcome outcome.borrower.encouraged {
  label: "Words of encouragement reach the borrower in her own language — attributably when the sender is public"
  steps_max: 2
  vocabulary: actor
  summary: "The lender writes and confirms (two steps); moderation, translation, and reveal happen inside the machine. Sender identity and the thank/return edge are gated by @user.profile_public per @decision.encouragement_sender_reveal; delivery is observed in code, attribution is not built."
  status: asserted
  confidence: 0.85
}

# --- actors -------------------------------------------------------------

actor lender {
  label: "Lender who funds loans and writes encouragement"
  status: observed
  confidence: 0.95
}

actor borrower {
  label: "Borrower who reads encouragement in their own language"
  status: observed
  confidence: 0.95
  summary: "Embodied 2026-08-10 for the /portal first-person layer (audit persona Rosa, es). Lexicon and monologue are DRAFTED from the audit's cold-reads — not practitioner-harvested."
  domainVocabulary: ["mi préstamo", "mi pago", "mensajes de ánimo", "el dinero llegó"]
  lexicon: [
    { contract_term: "funded percent / amount remaining", actor_term: "tu préstamo va al %{pct}% — faltan %{amount}", register_person: "tú, warm informal es", banned: false },
    { contract_term: "repayment schedule item", actor_term: "tu próximo pago", register_person: "tú", banned: false },
    { contract_term: "encouragement message", actor_term: "mensajes de ánimo", register_person: "tú", banned: false },
    { contract_term: "fundraising / disbursal / status", actor_term: "(never shown raw)", banned: true },
    { contract_term: "locale code badge ('EN')", actor_term: "se muestra en inglés — la traducción al español está en revisión", banned: true, homonym_warning: "a bare locale code is machine detail where actor phrasing belongs (audit L3)" }
  ]
  lexiconProvenance: "Drafted 2026-08-10 from the dashboard audit; verbatim_sentences empty until a real borrower narrates (harvest per locale — es first)"
  knowledgeBoundary: {
    availableNow: ["How funded her loan is", "What she owes next and when (once repaying)", "Approved messages in her language"]
    unavailableYet: ["Whether her campaign will fully fund", "Who wrote an anonymous message (gated by @user.profile_public)"]
  }
  perceptualChannels: [visual, textual]
  representativeWork: "Logged in with one loan fundraising and seven repaid (audit persona Rosa, default locale es)"
  interruptionAndTimeConstraints: ["Short phone sessions; may go weeks between visits"]
  authorityAndRiskBoundary: ["Reads her own loans and messages; repayment moves through her partner, not this surface"]
  evidenceLevel: agent_walked
}

actor moderator {
  label: "Rule-based content moderator (AI stand-in)"
  status: observed
  confidence: 0.95
  metadata: { impl: "Kiva.Moderation.moderate/1", note: "never silently rewrites" }
}

actor translator {
  label: "Machine translation service"
  status: observed
  confidence: 0.95
  metadata: { impl: "Kiva.Translation.machine_translate/3" }
}

actor partner {
  label: "Field partner authoring borrower updates"
  status: observed
  confidence: 0.95
  metadata: { note: "posts updates/outcomes via post_borrower_update -> Kiva.Updates.post_update/5" }
}

# --- capabilities -------------------------------------------------------

capability encouragement.write {
  label: "Write an encouragement message to a borrower"
  servesOutcome: @outcome.borrower.encouraged
  status: observed
  confidence: 0.95
}

capability encouragement.read_native {
  label: "Read approved encouragement in the borrower's preferred locale"
  servesOutcome: @outcome.borrower.encouraged
  status: observed
  confidence: 0.95
}

capability reveal.read_notifications {
  label: "Read lender reveal notifications (bell + feed)"
  servesOutcome: @outcome.lender.principal_back_to_relend
  status: observed
  confidence: 0.95
}

capability borrower_update.post {
  label: "Partner posts a borrower update that reveals to lenders"
  servesOutcome: @outcome.lender.principal_back_to_relend
  status: observed
  confidence: 0.95
  metadata: { note: "Kiva.Updates + post_borrower_update; localized borrower_updates(_lc) with on-demand translation. The update/outcome reveal is the emotional return that motivates relending." }
}

# --- truths -------------------------------------------------------------

truth encouragement.message {
  label: "Encouragement message record with moderation status and source locale"
  lifetime: archive
  authority: { mode: service, ref: @messaging.encouragement }
  visibility: [borrower, lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "encouragement_messages",
    fields: ["loan_id", "borrower_id", "sender_user_id", "moderation_status", "moderation_reason", "source_locale_code"],
    moderation_status: ["pending", "approved", "blocked", "flagged", "rejected"]
  }
}

truth encouragement.localization {
  label: "Per-locale body of an encouragement (source + machine translations)"
  lifetime: archive
  authority: { mode: service, ref: @translator }
  visibility: [borrower, lender, staff, system]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "encouragement_messages_lc",
    fields: ["locale_code", "is_source", "source_locale_code", "body", "translation_status"],
    translation_status: ["published", "machine", "needs_review", "draft"]
  }
}

truth borrower.preferred_locale {
  label: "Borrower's preferred locale, the target language for translation and reveal"
  lifetime: account
  authority: { mode: service, ref: @messaging.encouragement }
  visibility: [borrower, staff, system]
  status: observed
  confidence: 0.95
  metadata: { field: "borrowers.preferred_locale_code" }
}

truth moderation.verdict {
  label: "Moderation outcome: approved | rewrite-suggested | rejected"
  lifetime: run
  authority: { mode: service, ref: @moderator }
  visibility: [lender, system]
  status: observed
  confidence: 0.95
  metadata: { values: ["approved", "rewrite", "rejected"], note: "rewrite is a non-binding suggestion; sender keeps their words" }
}

truth moderation.audit_event {
  label: "Audit trail entry for message.approved / message.rejected"
  lifetime: archive
  authority: { mode: service, ref: @messaging.encouragement }
  visibility: [staff, admin, system]
  status: observed
  confidence: 0.95
  metadata: { impl: "Kiva.Audit.record/1", events: ["message.approved", "message.rejected", "message.flagged", "message.override_approved", "message.override_rejected"] }
}

truth notification {
  label: "A reveal routed to one actor via a surface (bell + feed)"
  lifetime: account
  authority: { mode: service, ref: @messaging.reveal_layer }
  visibility: [lender, system]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "notifications",
    fields: ["user_id", "type", "title", "body", "link", "read_at"],
    types: ["loan_funded", "repayment"]
  }
}

truth notification.unread_count {
  label: "Count of unread notifications, drives the nav bell badge"
  lifetime: account
  authority: { mode: service, ref: @messaging.reveal_layer }
  visibility: [lender]
  status: observed
  confidence: 0.95
  metadata: { impl: "Kiva.Notifications.unread_count/1" }
}

truth partner_notification {
  label: "Notification routed to a partner when staff act on their loan"
  lifetime: account
  authority: { mode: service, ref: @messaging.reveal_layer }
  visibility: [partner, system]
  status: observed
  confidence: 0.95
  metadata: { note: "Kiva.Notifications.notify_partner produces these on approve_loan_listing (loan_approved) and request_loan_changes (changes_requested); partners read them at /notifications." }
}

# --- policies -----------------------------------------------------------

policy never_silently_rewrite on @moderation.verdict {
  effect: deny
  status: observed
  confidence: 0.95
  rule: "The moderator never edits the sender's words: it approves, returns a non-binding rewrite suggestion, or blocks with a gentle reason. Blocked/flagged messages are now PERSISTED (held, source body in 'draft' status with the reason) so staff can review and override them — not silently discarded. Only an approved (or staff-overridden) message reaches the borrower."
}

policy persist_source_before_translate on @encouragement.localization {
  effect: require
  status: observed
  confidence: 0.95
  rule: "The source-locale body is persisted first (is_source=true, status=published); the borrower-locale row is created only when borrower_locale differs from source, marked machine."
}

policy reveal_only_approved on @encouragement.message {
  effect: require
  status: observed
  confidence: 0.95
  rule: "list_for_borrower / list_for_loan return only messages with moderation_status == 'approved'; the borrower never sees blocked or rewrite-pending content."
}

policy lender_only_authoring on @encouragement.message {
  effect: require
  status: observed
  confidence: 0.95
  rule: "submit_encouragement_message is restricted to actor role 'lender' (command registry actors + lender-gated form in LoanLive.Show)."
}

policy notify_funded_lenders on @notification {
  effect: require
  status: observed
  confidence: 0.95
  rule: "When a loan crosses to status 'funded', notify_loan_lenders emits a loan_funded notification to every distinct lender who funded it (Kiva.Portfolio)."
}

policy notify_repayment_lenders on @notification {
  effect: require
  status: observed
  confidence: 0.95
  rule: "When a repayment is recorded, notify_loan_lenders emits a repayment notification to every distinct lender of the loan (Kiva.Lending)."
}

policy mark_read_on_view on @notification.unread_count {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Opening /notifications calls mark_all_read, clearing the bell badge for that user."
}

# --- flows --------------------------------------------------------------

flow encouragement.submit {
  label: "Cross-language encouragement: moderate -> persist -> translate -> reveal"
  status: observed
  confidence: 0.95
  entry: drafted
  terminal: revealed
  state drafted
  state moderating
  state rejected
  state rewrite_suggested
  state source_persisted
  state translated
  state revealed

  step moderate {
    actor: @moderator
    reads: [@moderation.verdict]
    writes: [@moderation.audit_event]
  }
  step persist_source {
    actor: @messaging.encouragement
    reads: [@encouragement.message]
    writes: [@encouragement.message, @encouragement.localization]
  }
  step translate {
    actor: @translator
    reads: [@borrower.preferred_locale]
    writes: [@encouragement.localization]
  }
  step reveal {
    actor: @messaging.encouragement
    reads: [@encouragement.localization]
    writes: [@moderation.audit_event]
  }

  transition drafted -> moderating on submit_encouragement_message
  transition moderating -> rejected on verdict_rejected do [moderate, persist_source]
  transition moderating -> rewrite_suggested on verdict_rewrite do [moderate, persist_source]
  transition moderating -> source_persisted on verdict_approved do [moderate, persist_source]
  transition source_persisted -> translated on borrower_locale_differs do [translate]
  transition source_persisted -> revealed on borrower_locale_same do [reveal]
  transition translated -> revealed on translation_stored do [reveal]
}

flow moderation.override {
  label: "Staff reviews a held (blocked/flagged) message and overrides the AI verdict"
  status: observed
  confidence: 0.95
  entry: held
  terminal: resolved

  state held
  state approved_delivered
  state upheld_rejected

  transition held -> approved_delivered on approve_message do [translate, reveal]
  transition held -> upheld_rejected on reject_message
}

flow reveal.notify {
  label: "Lender reveal: loan funds or repays -> notify each lender"
  status: observed
  confidence: 0.95
  entry: loan_event
  terminal: read
  state loan_event
  state notified
  state surfaced
  state read

  step fan_out {
    actor: @messaging.reveal_layer
    reads: [@notification]
    writes: [@notification, @notification.unread_count]
  }
  step mark_read {
    actor: @lender
    reads: [@notification]
    writes: [@notification.unread_count]
  }

  transition loan_event -> notified on loan_funded do [fan_out]
  transition loan_event -> notified on repayment do [fan_out]
  transition notified -> surfaced on bell_rendered
  transition surfaced -> read on feed_opened do [mark_read]
}

flow borrower_update.publish {
  label: "Partner posts a borrower update/outcome that reveals to lenders"
  status: observed
  confidence: 0.95
  entry: drafted
  terminal: revealed
  state drafted
  state revealed
  transition drafted -> revealed on post_borrower_update
}

# --- commands -----------------------------------------------------------

command submit_encouragement_message {
  label: "Lender submits encouragement (moderate, translate, reveal)"
  servesOutcome: @outcome.borrower.encouraged
  eligibility: ["Actor role lender"]
  effects: ["Message created and moderated (never silently rewritten)", "Source persisted; borrower-locale machine row when locales differ", "Approved messages reveal to the borrower; held ones queue for staff", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: {
    actors: ["lender"],
    required: ["loan_id", "body", "source_locale_code"],
    preview_required: true,
    confirmation_required: true,
    side_effects: ["create_message", "run_moderation", "create_translations_if_approved", "notify_borrower_if_visible", "audit_event"],
    handler: "Kiva.Commands.run_handler/3 -> Kiva.Messaging.create_encouragement/4",
    returns: ["moderation: approved", "moderation: rejected (reason)", "moderation: rewrite (suggestion)"]
  }
}

command approve_message {
  label: "Staff override: approve a held encouragement and deliver it (staff/admin)"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["Actor role staff | admin", "Message is held (blocked/flagged)"]
  effects: ["AI verdict overridden; message translated and delivered to the borrower", "Audit event (message.override_approved)"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["staff", "admin"], required: ["message_id"], handler: "Kiva.Messaging.approve_message/1" }
}

command reject_message {
  label: "Staff override: uphold the block on a held encouragement (staff/admin)"
  servesOutcome: @outcome.staff.decisions_cleared
  eligibility: ["Actor role staff | admin", "Message is held (blocked/flagged)"]
  effects: ["Block confirmed; the borrower never sees the message", "Audit event (message.override_rejected)"]
  status: observed
  confidence: 0.95
  metadata: { actors: ["staff", "admin"], required: ["message_id"], handler: "Kiva.Messaging.reject_message/1" }
}

command record_repayment {
  label: "Record a repayment (producer of the repayment reveal)"
  servesOutcome: @outcome.partner.day_collected
  eligibility: ["Actor role partner | staff | admin"]
  effects: ["Repayment recorded; every lender of the loan receives the repayment reveal"]
  status: observed
  confidence: 0.95
  metadata: {
    actors: ["partner", "staff", "admin"],
    required: ["loan_id"],
    note: "triggers notify_loan_lenders(repayment) via Kiva.Lending; canonical declaration with full gates on the loan_lifecycle contract"
  }
}

command post_borrower_update {
  label: "Partner/staff posts a borrower update (kind: update|outcome) revealed to lenders"
  servesOutcome: @outcome.lender.principal_back_to_relend
  eligibility: ["Actor role partner | staff | admin (borrower direct authoring is open — @question.portal.borrower_update_authoring)"]
  effects: ["Localized update created (source LC row)", "Lenders notified — outcome kind reveals as a completion story (loan_outcome)", "Audit event"]
  status: observed
  confidence: 0.95
  metadata: {
    actors: ["partner", "staff", "admin"],
    handler: "Kiva.Updates.post_update/5",
    note: "on-demand translation like team posts; registered but NO surface for any role (audit H6 — command-coverage orphan)"
  }
}

# --- 2026-08-10: first-person layer — the borrower portal journey --------
# Seeded from docs/storytime/dashboard_first_person_audit_2026-08-10.md.
# practitioner_unvalidated: audit cold-reads are agent_walked evidence only.

story story.borrower.portal_checkin for @borrower {
  label: "Rosa opens her page: ¿ya llegó el dinero?"
  servesOutcome: @outcome.borrower.money_status_known
  practitionerGate: practitioner_unvalidated
  evidenceLevel: agent_walked
  sourceRefs: [@dashboard_first_person_audit]
  status: asserted
  confidence: 0.85
  summary: "The audited portal answers nothing and offers nothing (audit H6): no headline truth, zero available decisions, unattributed messages, completed loans as empty husks — and it rendered in English for an es-default borrower (audit H2). This journey is the corrective spine."
  screenplay: {
    id: "SPL-portal-habitual"
    mindset_variant: habitual
    register: "@borrower lexicon — tú, warm informal es; es is the SOURCE locale for every borrower string"
    beats: [
      { stage: @stage.portal.opening, screen_says: "Tu préstamo está al %{pct}% — faltan %{amount}. La campaña termina en %{days} días.", actor_thinks: "Ya casi. ¿Tengo que hacer algo?", actor_does: "Mira sus mensajes.", screen_replies: "%{sender} te escribió el %{date}: '¡Ánimo, Rosa!' — Responder gracias.", forces_truths: [@loan.fundraising_ends_at, @user.profile_public] },
      { stage: @stage.portal.opening, screen_says: "(repaying state) Tu próximo pago: %{date} · %{amount}. Vas al día.", actor_thinks: "Bien — al día.", actor_does: "Cierra tranquila.", screen_replies: "(nothing more needed — the answer WAS the visit)", forces_truths: [@repayment_schedule.item_terms] },
      { stage: @stage.portal.wrong_language, screen_says: "(today) 'Here are your loans in your language' — in English, to an es-default borrower.", actor_thinks: "Esto está en inglés — no entiendo qué me piden.", actor_does: "Busca cómo cambiar el idioma, o se va.", screen_replies: "(the globe dropdown exists; the betrayal is that she had already chosen — audit H2)", forces_truths: [] },
      { stage: @stage.portal.loan_closed, screen_says: "Pagaste %{total} en %{months} meses ✓ — préstamo completado.", actor_thinks: "Lo logré.", actor_does: "Cuenta cómo le fue.", screen_replies: "(post-update path — open: @question.portal.borrower_update_authoring)", forces_truths: [] }
    ]
    transcribed_keys: []
    note: "Stub (v1.12). The audit's verbatim transcription target is preserved on @stage.portal.opening; the state-dependent split (fundraising vs repaying headline) is the audit's own rethink rule, guarding against the M1 lifecycle leak."
  }
}

stage stage.portal.opening in @story.borrower.portal_checkin {
  label: "Portal open — ¿ya llegó el dinero?"
  interiorMonologue: {
    habitual: ["¿Ya llegó el dinero? ¿Cuánto falta?", "¿Cuánto pago y cuándo?", "¿Alguien dijo algo de mí?"]
    first_time: ["¿Esto es de verdad? ¿Dónde veo mi préstamo?"]
    returning_after_away: ["¿Pasó algo mientras no estuve? ¿Voy al día?"]
  }
  monologueProvenance: "habitual lines are the audit's derived seeds (verbatim from the audit doc, still model-authored); no practitioner verbatims yet"
  questionStack: [
    { q: "Is my money coming — how close is my loan?", answeredBy: [@loan.funded_amount_cents, @loan.fundraising_ends_at], today: "exists per-card, never headlined (audit: Law 23 miss — the headline answers nothing)" },
    { q: "What do I owe next, and when?", answeredBy: [@repayment_schedule.item_terms], today: "exists, buried mid-card — and leaks onto fundraising loans (audit M1); the answer is legal only in the repaying state (Law 14)" },
    { q: "Did anyone encourage me — who?", answeredBy: [@encouragement.localization, @user.profile_public], today: "messages shown but unattributed, no sender/date/loan, no thank path (audit H6); attribution ruled public-profile-gated (@decision.encouragement_sender_reveal)" },
    { q: "What should I do now?", answeredBy: [@decision.portal.post_update], today: "nothing offered — post_borrower_update is a registered command with NO surface anywhere (audit H6, command-coverage orphan)" }
  ]
  transcriptionTargets: ["es-source (audit verbatim): 'Tu préstamo está al 76% — faltan $225. Tu próximo pago: 28 dic · $118.75.' — rendered state-dependently per the audit's own rethink rule"]
  actorCanKnow: ["Funded percent and remaining amount", "Next payment once repaying", "Approved messages in her language"]
  actorCannotKnowYet: ["Whether the campaign will fund", "Anonymous senders' identity (gated)"]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.85
}

decision decision.portal.post_update at @stage.portal.opening {
  label: "Tell my supporters how it's going (post an update)"
  resolvesTo: [@post_borrower_update]
  exposure: primary
  status: asserted
  confidence: 0.8
  metadata: { note: "The registered command is partner/staff-only today; whether Rosa authors directly or requests via her partner is @question.portal.borrower_update_authoring (below); either way the portal offers the path." }
}

decision decision.portal.see_supporters at @stage.portal.opening {
  label: "See who encouraged me — and say thanks"
  resolvesTo: [@ask.portal.my_messages]
  exposure: secondary
  status: asserted
  confidence: 0.8
  metadata: { note: "The thank/acknowledge return edge has no registered command yet; it lands with @product.sender_reveal (public-profile-gated)." }
}

stage stage.portal.wrong_language in @story.borrower.portal_checkin {
  label: "Failure path: her page speaks the wrong language"
  summary: "An es-default borrower gets a sticky English portal because an anonymous session's en fallback shadows her account default (@finding.localization.locale_precedence_defeats_default, audit H2). Every borrower string in this journey presumes this is fixed."
  interiorMonologue: {
    something_wrong: ["Esto está en inglés — no entiendo qué me piden."]
  }
  questionStack: [
    { q: "Why is my page not in my language, and how do I fix it?", answeredBy: [@user.default_locale, @decision.portal.switch_language], today: "the globe dropdown works, but her stored choice should have won without any step" }
  ]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.85
}

decision decision.portal.switch_language at @stage.portal.wrong_language {
  label: "Ver esto en español (switch language)"
  resolvesTo: [@set_locale]
  exposure: contextual
  status: observed
  confidence: 0.9
  metadata: { note: "The escape hatch exists (globe dropdown -> set_locale); the real fix is upstream precedence, not this decision." }
}

stage stage.portal.loan_closed in @story.borrower.portal_checkin {
  label: "A loan completes — the closure moment"
  summary: "Completed loans currently render as empty husks (title + badge, no closure — audit H6). The stage owns the 'Repaid %{total} over %{months} months' moment and folds per Law 24 (count + state in the fold header)."
  interiorMonologue: {
    habitual: ["Lo logré — pagué todo.", "¿Les cuento cómo me fue?"]
  }
  questionStack: [
    { q: "Did I finish — what did I accomplish?", answeredBy: [@repayment_schedule.item_terms], today: "derivable from the paid schedule; never rendered as a closure line" }
  ]
  evidenceLevel: agent_walked
  status: asserted
  confidence: 0.8
}

decision decision.portal.post_final_update at @stage.portal.loan_closed {
  label: "Tell supporters how it turned out"
  resolvesTo: [@post_borrower_update]
  exposure: contextual
  status: asserted
  confidence: 0.8
  metadata: { note: "kind: outcome — reveals to lenders as a completion story (loan_outcome notification)." }
}

ask ask.portal.loan_status {
  label: "¿Cómo va mi préstamo? ¿Cuánto pago y cuándo?"
  visibility: [borrower]
  provenance: "PortalLive assigns over the borrower's loans + schedule (@loan.funded_amount_cents, @repayment_schedule.item_terms), state-guarded per Law 14"
  status: asserted
  confidence: 0.85
}

ask ask.portal.my_messages {
  label: "¿Quién me escribió, cuándo, sobre cuál préstamo?"
  visibility: [borrower]
  provenance: "Approved encouragement rows with date + loan; sender identity only when @user.profile_public (ruled, not built)"
  status: asserted
  confidence: 0.85
}

intent intent.portal.donde_va_mi_dinero for @borrower {
  label: "¿Ya llegó el dinero?"
  mode: ask
  phrasings: [
    "¿Ya llegó el dinero?"
    "¿Cuánto pago y cuándo?"
    "How close is my loan?"
  ]
  resolvesTo: [@ask.portal.loan_status]
  servesOutcome: @outcome.borrower.money_status_known
  availableAt: [@stage.portal.opening]
  maturity: candidate
  status: asserted
  confidence: 0.8
}

question question.portal.borrower_update_authoring on @decision.portal.post_update {
  questionType: open_question
  ask: "Does the borrower author updates directly from the portal, or request them via her partner? post_borrower_update is registered for partner/staff/admin only, and has no surface for anyone (audit H6)."
  whyItMatters: "Rosa's stack entry 'What should I do now?' resolves through this command; the actor list decides whether the portal grows an author box or a request-to-partner handoff."
  owner: "Paul Ericksen"
  neededBy: "The borrower portal rework"
  blocking: ["The portal's action row", "The command's surface (currently an orphan for every role)"]
  resolveWith: ["Product ruling on the actor list; then either extend the command's actors or add a request handoff"]
  knowledge: {
    scope: ["post_borrower_update actor list and surfaces"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-08-10"
    invalidatedBy: ["The ruling lands with a surface either way"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}

# --- 2026-08-10: product ruling owned by this subsystem ------------------

decision_record decision.encouragement_sender_reveal {
  decision: "The lender->borrower encouragement reveal edge carries sender identity (name/avatar) and a borrower thank/acknowledge return edge ONLY when the sending lender's profile is public; otherwise the message presents anonymously (current behavior stands). Forces a new truth: @user.profile_public, a lender-controlled visibility flag that does not exist in the schema yet — the reveal policy forces the schema."
  state: active
  authority: { mode: human, owner: "Paul Ericksen" }
  decidedAt: "2026-08-10"
  basedOn: [@dashboard_first_person_audit]
  alternatives: ["Always reveal sender identity", "Keep all messages anonymous with no thank path"]
  consequences: ["@user.profile_public must land in the identity schema (lender-controlled, default private)", "The borrower thank/acknowledge return edge becomes a registered command with a reveal to the sender", "Anonymous presentation remains the default for private senders"]
  revisitWhen: ["Profile visibility grows beyond a boolean", "Borrower-to-lender messaging expands past thank/acknowledge"]
  supersedes: []
  mandates: [@product.sender_reveal]
  status: confirmed
  confidence: 1.0
  metadata: { ruling: "owner, 2026-08-10 ('if the sender has public profile, yes'); audit Q1" }
}

# --- views --------------------------------------------------------------

view loan_encourage_form for @encouragement.submit {
  label: "Encouragement form + thread on the localized loan profile"
  status: observed
  confidence: 0.95
  metadata: { impl: "KivaWeb.LoanLive.Show", event: "encourage", gated: "role == lender" }
  affordances: [form, submit, message_thread]
  reveals: [@encouragement.localization, @moderation.verdict]
  commands: [submit_encouragement_message]
}

view moderation_queue for @story.staff.decision_sweep {
  label: "Staff encouragement moderation queue with override (AdminLive)"
  status: observed
  confidence: 0.95
  metadata: { impl: "KivaWeb.AdminLive", source: "Kiva.Messaging.list_moderation_queue/1" }
  affordances: [card, body_quote, reason, approve_button, reject_button]
  reveals: [@encouragement.message, @encouragement.localization, @moderation.verdict]
  commands: [approve_message, reject_message]
}

view borrower_portal for @story.borrower.portal_checkin {
  label: "Borrower native-language portal: loans + messages of encouragement"
  status: observed
  confidence: 0.95
  metadata: { impl: "KivaWeb.PortalLive", source: "Kiva.Messaging.list_for_borrower/2" }
  affordances: [loan_cards, message_list, machine_badge, fallback_badge]
  reveals: [@encouragement.localization, @borrower.preferred_locale]
  commands: []
}

view notifications_feed for @reveal.notify {
  label: "Lender reveal feed (funded loans, repayments)"
  status: observed
  confidence: 0.95
  metadata: { impl: "KivaWeb.NotificationsLive", route: "/notifications", on_mount: "mark_all_read" }
  affordances: [notification_list, type_icon, deep_link, unread_highlight]
  reveals: [@notification]
  commands: []
}

view nav_bell for @reveal.read_notifications {
  label: "Nav bell with unread badge (lender-only)"
  status: observed
  confidence: 0.95
  metadata: { impl: "KivaWeb.Layouts (app)", gated: "role == lender" }
  affordances: [bell_icon, unread_badge, link_to_feed]
  reveals: [@notification.unread_count]
  commands: []
}
```
