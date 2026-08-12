<!--
Canonical-For: lib/kiva/ai, lib/kiva_web/live/chat_live.ex, lib/kiva_web/schema.ex, lib/kiva/commands.ex
Status: ACTIVE
-->

# FractalFlow — AI Dialogue Subsystem

Models the implemented page-aware chat substrate: an assistant that **asks** via role-scoped GraphQL and **commands** only through the registered preview/confirm path, with every turn, tool call, and action preview persisted for admin reconstruction. Conversational turns are answered by a real model when the reader has connected one, and by a deterministic offline script when they have not; commands never touch the model.

2026-08-10: grammar upgrade + doc-fidelity: the chat surface is
KivaWeb.ChatLive (replaced ChatComponent in commit 044f9b2 — stale mentions
updated), and the launcher is currently DARK on every page —
live_render(ChatLive) commented out in root.html.heex (audit H1). The owner
ruled that a regression, not a decision: @decision.restore_chat_launcher
below, mandating @product.restore_chat.

2026-08-12: this contract described the assistant as a deterministic mock with
"no external provider in v1". That stopped being true when the real-model path
(Kiva.AI.LLM) was restored, and the gap went unrecorded through several
sessions — including one that changed the credential vocabulary. The backend,
its configuration truth, what it sends off-machine, and the setup reveal are
modelled below: @ai.model_endpoint declares the boundary itself, with
@ai.llm_backend as its in-process caller, @ai.llm_configuration as the truth
that decides whether it is reachable, @constraint.ai.no_traffic_without_explicit_configuration
on what may cross it, two obligations (@obligation.ai.model_failure_degrades_to_script,
@obligation.ai.unconfigured_copy_explains_setup), @ai.chat_assistant as the
agent surface, and @evidence.ai.llm_path_drift / @finding.ai.contract_understated_egress
on how the gap survived. The missing node kind was the mechanism: with no
`interface` declared, no part of the graph contradicted the prose.

```lssd
model kiva.ai_dialogue@0.4.0 {
  namespace: "kiva.ai_dialogue"
  revision: "2026-08-12"
  status: observed
  confidence: 0.9
}

module ai.dialogue {
  label: "AI dialogue subsystem"
  status: observed
  confidence: 0.95
  metadata: {
    engine: "Kiva.AI.Assistant — routes conversational turns to @ai.llm_backend when a model is connected, and to its own deterministic offline script otherwise; commands never reach the model",
    modes: ["ask", "command"],
    boundary: "reads through KivaWeb.Schema (role-scoped GraphQL); writes only through Kiva.Commands; the only egress is @ai.model_endpoint, and only when explicitly configured"
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

interface ai.model_endpoint {
  label: "External chat-completions service — the subsystem's only egress"
  status: observed
  confidence: 0.95
  reads: [@ai.llm_configuration]
  metadata: {
    protocol: "OpenAI-compatible POST /v1/chat/completions",
    resolution: ["KIVA_LLM_ENDPOINT if set", "the hosted provider if OPENAI_API_KEY is set", "otherwise http://127.0.0.1:1234 — loopback, a model on the same machine"],
    model: "gpt-4o-mini by default; OPENAI_MODEL overrides",
    crosses_outbound: ["assembled system prompt: role additions + moderation contract + page label + locale + demo disclaimer", "the last 10 user/assistant turns of this conversation"],
    crosses_inbound: ["one assistant message, or nothing usable"],
    authentication: "Bearer credential when one is configured; no authorization header at all when none is",
    never_crosses: ["command execution — the model cannot mutate; it is not given tools and its reply is never parsed as an action"],
    off_machine_only_when: "@constraint.ai.no_traffic_without_explicit_configuration is satisfied by a deliberate act"
  }
}

system ai.llm_backend {
  label: "In-process client for the model endpoint (Kiva.AI.LLM)"
  status: observed
  confidence: 0.95
  calls: [@ai.model_endpoint]
  reads: [@ai.llm_configuration, @ai.page_context, @ai.actor_role, @ai.message]
  writes: [@ai.tool_call]
  obligations: [@obligation.ai.model_failure_degrades_to_script]
  metadata: {
    module: "Kiva.AI.LLM",
    scope: "conversational ask turns and the API-docs query only — set_locale and lend stay on the deterministic preview/confirm path",
    audited: "every attempt writes an ai_tool_calls row (tool_type llm, schema_surface llm, operation chat.completions), successes and failures alike"
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
    tool_types: ["graphql_query", "command_preview", "llm"],
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

truth ai.llm_configuration {
  label: "Whether this copy has a model connected, and where it lives"
  lifetime: run
  authority: { mode: human, ref: @ai.llm_backend }
  visibility: [system, admin]
  status: observed
  confidence: 0.95
  metadata: {
    source_of_truth: "the process environment, read at call time — never persisted, never settable from any surface",
    configured_when: "any of OPENAI_API_KEY, KIVA_LLM_ENDPOINT, LLM_API_TOKEN, LLM_API_TOKEN_FILE is set and non-empty",
    credential_precedence: ["OPENAI_API_KEY", "LLM_API_TOKEN", "LLM_API_TOKEN_FILE — a file holding the raw token or an API_TOKEN=... line"],
    unconfigured_behaviour: "no authorization header is sent at all, which is what a model on the same machine expects",
    kill_switch: "config :kiva, :ai_llm_enabled, false — a deliberate off, held distinct from an unconfigured copy so tests and demos are not told to go set a key",
    three_states: ["configured — the model answers", "unconfigured — the script answers and explains setup", "switched off — the script answers and says nothing"]
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
  state model_attempted
  state intent_classified
  state graphql_run
  state answer_returned
  state out_of_scope
  state setup_explained

  step ask_model {
    actor: @ai.assistant
    reads: [@ai.llm_configuration, @ai.page_context, @ai.actor_role, @ai.message]
    writes: [@ai.tool_call]
  }
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

  transition actor_question -> model_attempted on conversational_turn do [ask_model]
  transition model_attempted -> answer_returned on model_replied
  transition model_attempted -> intent_classified on model_absent_or_failed do [classify]
  transition intent_classified -> graphql_run on loans_or_faq_intent do [run_scoped_graphql]
  transition intent_classified -> graphql_run on portfolio_intent do [run_scoped_graphql]
  transition graphql_run -> answer_returned on data_summarized
  transition intent_classified -> out_of_scope on lender_only_intent_without_role
  transition out_of_scope -> answer_returned on prompt_sign_in
  transition intent_classified -> setup_explained on no_scripted_intent_and_no_model_connected
  transition setup_explained -> answer_returned on setup_instructions_returned
}

# --- 2026-08-10: product ruling owned by this subsystem ------------------

obligation obligation.commands.execute_regates_and_audits on @ai.command_registry {
  label: "Every execute re-runs every gate and leaves an audit row"
  trigger: "Any call to Kiva.Commands.execute/4, from any surface — UI button, chat confirmation, bulk action, or API"
  requirement: "Re-run check_role, check_required, and check_eligibility before the handler, treating whatever preview said as advisory rather than trusted, and write an Audit.record on success carrying actor, role, event_type command.<key>, target, redacted params, and the command's declared side_effects."
  completion: "Kiva.Commands.execute/4 — a single `with` chain where the audit write is unreachable unless all three gates and the handler succeeded, so a passing command cannot skip its record."
  rationale: "Preview runs against state that may have moved by the time someone confirms, and a chat confirmation can arrive minutes later. Re-gating is what makes preview safe to show widely; the audit row is what makes the mutation reconstructable afterwards. Both were true in code but lived only in a metadata string, where nothing would notice their loss."
  status: observed
  confidence: 0.95
}

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
  invalidatedBy: ["Resolved 2026-08-11 by @policy.commands.state_preconditions_declared: 17 of the 18 gained state gates, and the 18th is recorded as genuinely having none."]
  strength: conclusive
  status: retired
  confidence: 1.0
}

policy policy.commands.state_preconditions_declared {
  label: "A command declares the state its target must be in, or records that it has none"
  appliesTo: [@ai.command_registry]
  rule: "Every command in the registry declares eligibility covering: the target exists, the values it is given are ones the domain accepts, the target is in a state where the action means something, and the actor stands in the right relationship to it. A command with genuinely no state precondition says so explicitly rather than leaving an empty list that cannot be told apart from an oversight."
  rationale: "Eighteen of twenty-four commands declared nothing. Role and required-input checks still ran, so this was never an authorisation hole, but a stale id from a queue somebody else had already cleared either mutated something or crashed the handler on Repo.get!, and set_partner_status would persist any string at all into a status column with no validate_inclusion behind it."
  enforcement: "test/kiva/command_state_gates_test.exs \u2014 nine cases, every one of which fails when the eligibility lists are emptied. Partner and Trustee changesets additionally gained validate_inclusion on status, so the schema refuses a bad value even if a future caller skips the command layer."
  status: observed
  confidence: 1.0
}

decision_record decision.commands.disbursal_does_not_require_full_funding {
  label: "Disbursal is gated on not-yet-disbursed, not on being fully funded"
  status: observed
  confidence: 1.0
  summary: "The first draft of loan_awaiting_disbursal refused to disburse a loan that had not finished raising. A test caught it, and the test was right: field partners routinely disburse before the crowd finishes funding and are repaid afterwards, which is why the model carries direct_disbursal_pending at all, and the loan page offers the action on exactly one condition \u2014 nothing disbursed yet. The gate now quotes that condition instead of inventing a stricter one. Recorded because the stricter rule looks more careful and is wrong."
}

question question.commands.advance_demo_time_precondition on @ai.command_registry {
  questionType: open_question
  question: "advance_demo_time is the one command with no state precondition. Should it have one \u2014 for instance refusing to run outside a demo environment, or when a previous advance is still settling?"
  whyItMatters: "It is declared high risk and steps every active loan through its lifecycle in one call. Nothing about the target's state makes it illegal today, so no gate was invented; the honest answer may be that it needs an environment guard rather than a state guard."
  blocks: []
  status: asserted
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

# --- 2026-08-12: the real-model path, modelled ---------------------------

constraint constraint.ai.no_traffic_without_explicit_configuration {
  constraintType: privacy
  statement: "Nothing leaves the machine unless the reader has set an environment variable that names somewhere to send it. A copy with nothing configured makes no outbound request — it does not probe, retry, or fall back to a hosted provider."
  appliesTo: [@ai.llm_backend, @ai.llm_configuration]
  consequence: ["Conversation text and page context reach a third party only on a deliberate act (OPENAI_API_KEY, or KIVA_LLM_ENDPOINT pointed off-machine)", "The default endpoint is loopback, so the out-of-the-box path cannot leave the laptop even when a local model is running"]
  verification: ["Kiva.AI.LLM.answer/1 returns nil before any transport when configured?/0 is false (code read 2026-08-12)"]
  knowledge: {
    scope: ["every conversational turn"]
    evidence: [@evidence.ai.llm_path_drift]
    owner: "Paul Ericksen"
    learnedAt: "2026-08-12"
  }
  status: observed
  confidence: 0.95
}

obligation obligation.ai.model_failure_degrades_to_script on @ai.llm_backend {
  label: "A model that is missing, off, or broken never costs the reader their turn"
  trigger: "Any conversational turn where the model is switched off, unconfigured, unreachable, erroring, or returns something unusable"
  requirement: "Answer nil for every one of those failure modes alike and let Kiva.AI.Assistant continue into its deterministic script. No failure may surface as an error, a spinner, or a dead turn, and the attempt is still written to ai_tool_calls with its denial_reason."
  completion: "Kiva.AI.LLM.answer/1 guards on enabled?/0; do_answer/1 maps {:error, reason} to nil after recording. Not yet held by a test that fails when the fallback is removed — @question.ai.fallback_has_no_biting_test."
  rationale: "The assistant is a demo surface on someone else's laptop, so no model at all is the normal state rather than an exception — and the deterministic command path deliberately sits above the model, keeping preview/confirm independent of whether one answers."
  status: observed
  confidence: 0.95
}

obligation obligation.ai.unconfigured_copy_explains_setup on @ai.respond {
  label: "A copy with no model says how to connect one, once the script runs out"
  trigger: "A turn falls past every scripted intent while needs_setup?/0 is true"
  requirement: "Reply with the concrete setup text — the exact variables, one command, and what changes — rather than repeating the capability menu the reader just fell off the end of. A copy switched off deliberately (ai_llm_enabled false) is not told to go set a key."
  completion: "Kiva.AI.Assistant.fallback/1 + setup_instructions/0; ChatLive assigns needs_setup at mount and @floating_chat_widget reveals it."
  rationale: "Anyone running this is running it locally, where the honest answer to 'why is the assistant dumb' is a missing key. Repeating the menu reads as the product being broken rather than unconfigured."
  status: observed
  confidence: 0.95
}

agent_surface ai.chat_assistant for @ai.respond {
  label: "The embedded page-aware assistant"
  mode: embedded
  status: observed
  confidence: 0.95
  reads: [@ai.page_context, @ai.actor_role, @ai.message, @ai.llm_configuration]
  commands: [@ai.command_spec]
  obligations: [@obligation.ai.unconfigured_copy_explains_setup]
  metadata: {
    scoped_context: "one conversation, the current page, the signed-in role, the active locale, and the last 10 turns — nothing from other users or other conversations",
    canonical_binding: "reads only through KivaWeb.Schema under the role gate; mutates only through Kiva.Commands preview/confirm",
    creates_no_alternate_semantics: "the model is given no tools and its reply is never parsed into an action; command intent is matched deterministically before the model is consulted at all",
    external_exposure: "none — there is no external agent/tool endpoint for this surface"
  }
}

question question.ai.fallback_has_no_biting_test on @ai.llm_backend {
  questionType: open_question
  question: "Should the degrade-to-script path carry a test that fails when it is removed — a stubbed backend that raises or returns an error, asserting the reader still gets a scripted answer?"
  whyItMatters: "It is the path almost every reader of this repo will take, and it is currently held up by a code shape rather than by anything that would notice if a refactor let a provider error escape."
  blocks: []
  status: asserted
  confidence: 1.0
}

evidence evidence.ai.llm_path_drift {
  kind: observation
  occurredAt: "2026-08-12"
  subject: @ai.dialogue
  method: "Asked whether the contract still matched the code after a session that renamed the LLM client's configuration vocabulary; read Kiva.AI.LLM, Kiva.AI.Assistant, Kiva.AI.DocsAssistant and ChatLive against every node in this contract."
  observation: "The contract carried no representation of the real-model path at all. Its module metadata asserted 'deterministic rule-based mock LLM, no external provider in v1' while Kiva.AI.LLM had been talking to an OpenAI-compatible endpoint for some time; ai.tool_call declared two tool_types where the code writes three; the ask_mode flow began at intent classification, skipping the model attempt that actually runs first; and neither the configuration truth nor the setup reveal existed. The stale claim was the load-bearing one — a reader auditing this subsystem for data egress would have concluded from the contract that there was none."
  provenance: { doc: "session 2026-08-12, owner asked whether FractalFlow obligations had been met" }
  scope: ["lib/kiva/ai"]
  status: observed
  confidence: 1.0
}

finding finding.ai.contract_understated_egress {
  label: "The contract denied an egress the code had"
  derivedFrom: [@evidence.ai.llm_path_drift]
  claim: "Between the restoration of the real-model path and 2026-08-12, this contract asserted that the subsystem had no external provider while the code was posting conversation history and page context to a chat-completions endpoint. The absence of an @interface node was the mechanism: with no explicit boundary declared, nothing in the graph contradicted the module metadata's claim, and the drift survived several sessions — including one that renamed the very configuration it failed to model."
  limitations: ["Only lib/kiva/ai was re-read against its contract; the other nine contracts were checked for stale revision stamps and for this session's features, not line-by-line against their code"]
  invalidatedWhen: "A boundary check runs in CI — asserting every outbound HTTP call site in lib/ traces to a declared @interface node — and passes"
  status: observed
  confidence: 0.95
}

# --- views ----------------------------------------------------------

view floating_chat_widget for @ai.respond {
  label: "Floating page-aware chat widget (KivaWeb.ChatLive)"
  status: observed
  confidence: 0.95
  affordances: [toggle_open, message_input, send, confirm_button]
  reveals: [@ai.message, @ai.action_preview, @ai.page_context, @ai.actor_role, @ai.llm_configuration]
  commands: [send, confirm_command, toggle]
  obligations: [@obligation.ai.unconfigured_copy_explains_setup]
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
