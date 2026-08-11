<!--
Canonical-For: lib/kiva/ai, lib/kiva_web/live/chat_live.ex, lib/kiva_web/schema.ex, lib/kiva/commands.ex
Status: ACTIVE
-->

# FractalFlow — AI Dialogue Subsystem

Models the implemented page-aware chat substrate: a deterministic mock-LLM assistant that **asks** via role-scoped GraphQL and **commands** only through the registered preview/confirm path, with every turn, tool call, and action preview persisted for admin reconstruction.

2026-08-10: grammar upgrade + doc-fidelity: the chat surface is
KivaWeb.ChatLive (replaced ChatComponent in commit 044f9b2 — stale mentions
updated), and the launcher is currently DARK on every page —
live_render(ChatLive) commented out in root.html.heex (audit H1). The owner
ruled that a regression, not a decision: @decision.restore_chat_launcher
below, mandating @product.restore_chat.

```lssd
model kiva.ai_dialogue@0.3.0 {
  namespace: "kiva.ai_dialogue"
  revision: "2026-08-10"
  status: observed
  confidence: 0.9
}

module ai.dialogue {
  label: "AI dialogue subsystem"
  status: observed
  confidence: 0.95
  metadata: {
    engine: "Kiva.AI.Assistant (deterministic rule-based mock LLM, no external provider in v1)",
    modes: ["ask", "command"],
    boundary: "reads through KivaWeb.Schema (role-scoped GraphQL); writes only through Kiva.Commands"
  }
}

system ai.command_registry {
  label: "Command registry — the single audited mutation path"
  status: observed
  confidence: 0.95
  metadata: {
    module: "Kiva.Commands",
    invariant: "Every mutation (chat, button, dropdown, bulk action) converges on preview/3 + execute/4",
    gates: ["check_role", "check_required", "check_eligibility", "run_handler"],
    re_gates_on_execute: true,
    audited: "Audit.record on every successful execute"
  }
}

system ai.graphql_surface {
  label: "Role-scoped GraphQL read surface"
  status: observed
  confidence: 0.95
  metadata: {
    module: "KivaWeb.Schema",
    public_fields: ["viewer", "localizedLoans", "localizedLoan", "localizedPartner", "faqEntries"],
    staff_admin_fields: ["staffReviewQueueCount", "loanReviewQueue"],
    admin_fields: ["auditEvents", "permissionOutliers"],
    gate: "KivaWeb.Schema.Middleware.Authorize"
  }
}

actor ai.assistant {
  label: "Page-aware assistant (service actor)"
  status: observed
  confidence: 0.95
  metadata: {
    module: "Kiva.AI.Assistant",
    capabilities: ["detect intent", "run scoped GraphQL", "build command preview", "propose confirm action"],
    cannot: "mutate domain state directly"
  }
}

actor ai.lender {
  label: "Authenticated lender conversing with the assistant"
  status: observed
  confidence: 0.95
  metadata: { role: "lender", command_intents: ["complete_demo_lend", "set_locale"], ask_intents: ["portfolio summary", "almost-funded loans"] }
}

actor ai.public_visitor {
  label: "Anonymous / unauthenticated chat participant"
  status: observed
  confidence: 0.95
  metadata: { role: "public", reads: "public GraphQL surface only", command_intents: ["set_locale"] }
}

# --- capabilities ---------------------------------------------------

capability ai.respond {
  label: "Handle one user turn (Kiva.AI.Assistant.respond/2)"
  servesOutcome: @outcome.actor.ask_and_act_in_place
  status: observed
  confidence: 0.95
  metadata: {
    ctx: ["conversation_id", "actor", "role", "locale", "page"],
    routing: "cond over set_locale | lend | portfolio | loans | faq | help | fallback",
    returns: "%{reply, mode: ask|command, action: nil|confirm_command}"
  }
}

# --- truths ---------------------------------------------------------

truth ai.conversation {
  label: "Persisted chat session (ai_conversations)"
  lifetime: session
  authority: { mode: service, ref: @ai.dialogue }
  visibility: [system, staff, admin]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "Kiva.AI.Conversation",
    fields: ["user_id", "actor_role(default public)", "locale_code(default en)", "page_context"],
    relation: "has_many messages"
  }
}

truth ai.message {
  label: "Per-turn message log (ai_messages)"
  lifetime: session
  authority: { mode: service, ref: @ai.dialogue }
  visibility: [system, staff, admin]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "Kiva.AI.Message",
    fields: ["role(user|assistant)", "mode(user|ask|command)", "content", "metadata(action)"],
    insert_only: true
  }
}

truth ai.tool_call {
  label: "Audited GraphQL/command-preview tool call (ai_tool_calls)"
  lifetime: archive
  authority: { mode: service, ref: @ai.command_registry }
  visibility: [system, staff, admin]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "Kiva.AI.ToolCall",
    tool_types: ["graphql_query", "command_preview"],
    fields: ["schema_surface", "operation_name", "allowed(boolean)", "denial_reason", "request", "response_summary"],
    note: "Both allowed AND denied calls are logged (allowed:false + denial_reason)",
    admin_inspector: "Kiva.AI.recent_tool_calls/1"
  }
}

truth ai.action_preview {
  label: "Safe command preview proposed for confirmation (ai_action_previews)"
  lifetime: session
  authority: { mode: service, ref: @ai.command_registry }
  visibility: [system, staff, admin]
  status: observed
  confidence: 0.95
  metadata: {
    schema: "Kiva.AI.ActionPreview",
    fields: ["command_key", "target_type", "target_id", "preview(map)", "risk_level", "confirmed_at", "executed_at"],
    lifecycle: "create -> mark_preview_confirmed -> mark_preview_executed"
  }
}

truth ai.page_context {
  label: "Page-aware context captured at conversation start"
  lifetime: session
  authority: { mode: service, ref: @ai.dialogue }
  visibility: [system, staff]
  status: observed
  confidence: 0.9
  metadata: { source: "ChatLive assigns page -> conversation.page_context['page'] (ChatLive replaced ChatComponent in 044f9b2)" }
}

truth ai.actor_role {
  label: "Actor role threaded into GraphQL context and command gates"
  lifetime: session
  authority: { mode: admin, ref: @identity.access }
  visibility: [system, staff, admin]
  status: observed
  confidence: 0.95
  metadata: { values: ["public", "borrower", "lender", "partner", "staff", "admin"], used_by: ["Authorize middleware", "Commands.check_role", "surface_for/1"] }
}

truth ai.command_spec {
  label: "Declared command registry entry (the Kiva.Commands registry module attribute)"
  lifetime: system
  authority: { mode: service, ref: @ai.command_registry }
  visibility: [system, staff, admin]
  status: observed
  confidence: 0.95
  metadata: {
    per_command: ["risk", "actors", "required", "preview_required", "confirmation_required", "eligibility", "side_effects"],
    mirrors: "schemas/command_registry.yaml"
  }
}

# --- policies -------------------------------------------------------

policy ai_no_direct_mutation on @ai.dialogue {
  effect: deny
  status: observed
  confidence: 0.95
  rule: "The assistant never writes domain state directly. It may only Commands.preview/3 and propose a confirm action; execution runs through Commands.execute/4 only after the actor clicks confirm in ChatLive.handle_event(\"confirm_command\")."
}

policy ai_scoped_graphql_only on @ai.dialogue {
  effect: require
  status: observed
  confidence: 0.95
  rule: "All AI data retrieval runs Absinthe.run against KivaWeb.Schema with context %{actor_role, locale, current_user}. The model never reads outside the actor's surface; each run is recorded as a graphql_query tool call with schema_surface."
}

policy command_registry_single_path on @ai.command_registry {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Every mutation converges on the registry. preview/3 and execute/4 both run check_role -> check_required -> check_eligibility; execute re-runs all gates (preview is advisory, not trusted) before run_handler and writes an Audit event on success."
}

policy graphql_role_gate on @ai.graphql_surface {
  effect: deny
  status: observed
  confidence: 0.95
  rule: "Authorize middleware checks resolution.context[:actor_role] against the field's allowed_roles; staff/admin and admin-only fields return 'unauthorized' otherwise. The client is never the boundary — the middleware is."
}

policy tool_calls_audited on @ai.tool_call {
  effect: require
  status: observed
  confidence: 0.95
  rule: "Both permitted and denied tool calls are persisted: allowed graphql/preview calls record request + response_summary; denied ones record allowed:false + denial_reason (inspect of GraphQL errors or command error)."
}

# --- flows ----------------------------------------------------------

flow ai.command_mode {
  label: "AI Command Mode — lend via chat (complete_demo_lend preview + confirm)"
  status: observed
  confidence: 0.95
  entry: actor_intent
  terminal: command_complete

  state actor_intent
  state loan_resolved
  state preview_built
  state preview_proposed
  state confirmed
  state command_executed
  state command_failed
  state command_complete

  step detect_lend {
    actor: @ai.assistant
    reads: [@ai.page_context]
    writes: [@ai.message]
  }
  step resolve_loan {
    actor: @ai.assistant
    reads: [@ai.command_spec]
    writes: []
  }
  step build_preview {
    actor: @ai.command_registry
    reads: [@ai.command_spec, @ai.actor_role]
    writes: [@ai.action_preview, @ai.tool_call]
  }
  step execute_command {
    actor: @ai.command_registry
    reads: [@ai.action_preview, @ai.command_spec]
    writes: [@ai.action_preview]
  }

  transition actor_intent -> loan_resolved on lend_intent_detected do [detect_lend, resolve_loan]
  transition loan_resolved -> preview_built on loan_found do [build_preview]
  transition loan_resolved -> command_complete on loan_not_found
  transition preview_built -> preview_proposed on confirm_action_emitted
  transition preview_built -> command_complete on preview_denied
  transition preview_proposed -> confirmed on actor_clicks_confirm
  transition confirmed -> command_executed on command_success do [execute_command]
  transition confirmed -> command_failed on command_failure
  transition command_executed -> command_complete on respond_success
  transition command_failed -> command_complete on respond_failure
}

flow ai.set_locale_command {
  label: "AI Command Mode — set_locale (low risk, confirm then redirect)"
  status: observed
  confidence: 0.95
  entry: language_intent
  terminal: locale_applied

  state language_intent
  state preview_ready
  state confirmed
  state locale_applied
  state command_failed

  step preview_locale {
    actor: @ai.command_registry
    reads: [@ai.command_spec]
    writes: [@ai.action_preview, @ai.tool_call]
  }

  transition language_intent -> preview_ready on language_code_detected do [preview_locale]
  transition language_intent -> command_failed on preview_error
  transition preview_ready -> confirmed on actor_clicks_confirm
  transition confirmed -> locale_applied on execute_success_then_redirect
  transition confirmed -> command_failed on execute_error
}

flow ai.ask_mode {
  label: "AI Ask Mode — scoped GraphQL Q&A (loans / faq / portfolio / almost-funded)"
  status: observed
  confidence: 0.95
  entry: actor_question
  terminal: answer_returned

  state actor_question
  state intent_classified
  state graphql_run
  state answer_returned
  state out_of_scope

  step classify {
    actor: @ai.assistant
    reads: [@ai.page_context, @ai.actor_role]
    writes: [@ai.message]
  }
  step run_scoped_graphql {
    actor: @ai.assistant
    reads: [@ai.actor_role]
    writes: [@ai.tool_call]
  }

  transition actor_question -> intent_classified on intent_detected do [classify]
  transition intent_classified -> graphql_run on loans_or_faq_intent do [run_scoped_graphql]
  transition intent_classified -> graphql_run on portfolio_intent do [run_scoped_graphql]
  transition graphql_run -> answer_returned on data_summarized
  transition intent_classified -> out_of_scope on lender_only_intent_without_role
  transition out_of_scope -> answer_returned on prompt_sign_in
}

# --- 2026-08-10: product ruling owned by this subsystem ------------------

policy policy.commands.unknown_gate_is_refused {
  label: "An eligibility check that does not exist refuses the command"
  appliesTo: [@ai.command_registry]
  rule: "Kiva.Commands.Eligibility answers an unrecognised check name with {:error, {:unknown_eligibility_check, name}}. A build-failing test walks every command in the registry and asserts each name it declares resolves to a real clause."
  rationale: "The catch-all previously answered :ok, so a gate whose name was misspelled, renamed, or never implemented read as enforced while doing nothing \u2014 which is exactly how approve_loan_listing shipped for months naming a translation gate that never ran. A gate is only as good as the spelling of its name."
  enforcement: "test/kiva/eligibility_checks_test.exs, proven to fail when a command names a check with no clause."
  status: observed
  confidence: 1.0
}

finding finding.commands.state_gates_are_sparse {
  claim: "Sixteen of twenty-four commands declare no state preconditions at all, including three high-risk ones (advance_demo_time, set_partner_status, revoke_permission). Role and required-input checks still run, so this is missing state validation rather than missing authorisation."
  basedOn: [@evidence.commands.eligibility_coverage_audit]
  scope: ["The command registry as of 2026-08-11"]
  supports: ["Commands whose handlers mutate without asking whether the target is in a legal state: record_repayment, record_disbursal, approve_translation, approve_message, set_trustee_status"]
  contradicts: []
  limitations: ["Which states are legal for each command is a product decision and was NOT invented here. The audit fixed the mechanism (unknown checks refuse) and left the coverage question open."]
  invalidatedBy: ["A pass that decides and declares the legal precondition for each ungated command, or records that it genuinely has none"]
  strength: conclusive
  status: observed
  confidence: 1.0
}

evidence evidence.commands.eligibility_coverage_audit {
  kind: observation
  occurredAt: "2026-08-11"
  subject: @ai.command_registry
  method: "Cross-referenced every eligibility name declared in the registry against the clauses implemented in Kiva.Commands.Eligibility, and read the handlers of the ungated high-risk commands to see whether they guard state themselves."
  observation: "No declared name was missing an implementation, so no gate was failing open through a typo at audit time. The exposure was structural: the catch-all returned :ok. Eight checks are implemented and all eight are referenced; no dead checks. Sixteen commands declare an empty eligibility list, and the handlers of the high-risk ones (revoke_permission, set_partner_status, advance_demo_time) perform their mutation without a state precondition."
  provenance: { doc: "session 2026-08-11, requested audit" }
  scope: ["24 commands"]
  status: observed
  confidence: 1.0
}

decision_record decision.restore_chat_launcher {
  decision: "Chat launcher darkness is a regression, not a decision: the commented-out live_render(ChatLive) in root.html.heex ('hidden for now') was never a product ruling; the chat-first pillar requires the launcher restored on every page that passes live_chat."
  state: active
  authority: { mode: human, owner: "Paul Ericksen" }
  decidedAt: "2026-08-10"
  basedOn: [@dashboard_first_person_audit]
  alternatives: ["Ratify the dark launcher as a product decision", "Restore chat on some surfaces only"]
  consequences: ["live_render(KivaWeb.ChatLive) returns to root.html.heex", "Every live_chat page regains Ask Mode + Command Mode (preview -> confirm)", "A launcher-present regression test guards it (audit Law-16 note)"]
  revisitWhen: ["The chat surface is redesigned or replaced"]
  supersedes: []
  mandates: [@product.restore_chat]
  status: confirmed
  confidence: 1.0
  metadata: { ruling: "owner, 2026-08-10 (unaware the launcher was dark); audit Q4 + H1" }
}

# --- views ----------------------------------------------------------

view floating_chat_widget for @ai.respond {
  label: "Floating page-aware chat widget (KivaWeb.ChatLive)"
  status: observed
  confidence: 0.95
  affordances: [toggle_open, message_input, send, confirm_button]
  reveals: [@ai.message, @ai.action_preview, @ai.page_context, @ai.actor_role]
  commands: [send, confirm_command, toggle]
  metadata: {
    placement: "fixed bottom-4 right-4 z-50 floating bubble + card",
    confirm: "phx-click confirm_command with preview-id -> Commands.execute",
    set_locale_confirm: "redirects to /locale/:code",
    impl_note: "KivaWeb.ChatLive replaced ChatComponent in commit 044f9b2",
    mount_regression: "2026-08-10: the component exists and works, but its live_render in root.html.heex is commented out ('hidden for now') — unreachable from every surface (audit H1). Restore ruled by @decision.restore_chat_launcher / @product.restore_chat (product ledger)"
  }
}

view ai_tool_call_inspector for @ai.respond {
  label: "Admin AI tool-call reconstruction (AdminLive)"
  status: observed
  confidence: 0.95
  affordances: [table, inspect_button, conversation_panel, denial_reason]
  reveals: [@ai.tool_call, @ai.message]
  commands: []
  metadata: {
    list: "Kiva.AI.recent_tool_calls/1",
    drill_down: "Kiva.AI.get_conversation!/1 + Kiva.AI.list_tool_calls/1 — surfaces persisted messages and both allowed and denied (denial_reason) tool calls per conversation"
  }
}
```
