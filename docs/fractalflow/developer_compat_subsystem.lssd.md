<!--
Canonical-For: lib/kiva_web/controllers/kiva_v1, lib/kiva_web/kiva_graphql, lib/kiva_web/live/developer_live.ex, lib/kiva_web/controllers/oauth_controller.ex
Status: ACTIVE
-->

# FractalFlow — Developer Portal & Kiva-Compat Subsystem (skeleton)

Skeleton contract authored 2026-08-10, resolving the product contract's open
question @question.docs.developer_subsystem_contract. Everything here is
derived from the product contract's observed capability claims
(@capability.developer_portal, @capability.kiva_api_compat, shipped 5efb1f1
and 375e99d..044f9b2) and the tested-scope qualification
(@capability_qualification.kiva_api_compat) — NOT from a fresh code read, so
new decomposition below is `asserted`. Grow this under the touched-story rule
on the next substantive change to /developer, /v1, /graphql, or /oauth.

```lssd
model kiva.developer_compat@0.1.0 {
  namespace: "kiva.developer_compat"
  revision: "2026-08-10"
  status: asserted
  confidence: 0.8
}

module developer.compat {
  label: "Developer portal + Kiva-compatible external API"
  contains: [@capability.developer_portal, @capability.kiva_api_compat]
  status: asserted
  confidence: 0.85
  summary: "Self-enabled developer capability (/developer dashboard, OAuth-client apps, API keys, GraphiQL, machine-readable docs) plus the legacy-compatible external surface (/v1 REST, root /graphql mirror, /oauth) that lets unmodified legacy clients (KivaLens) run against Kredo."
}

actor actor.developer {
  label: "External developer (human or agent) integrating against the public surface"
  status: asserted
  confidence: 0.8
  summary: "Skeleton embodiment: works from docs + keys, not the product UI; the agent variant consumes GET /developers/agents.md. Embody fully (vocabulary, boundaries, lexicon) when the developer journey is grown."
}

outcome outcome.developer.integrated {
  label: "A developer (or agent) integrates against the same registry the UI uses — keys, OAuth, docs, manifest — without asking a human"
  steps_max: 3
  vocabulary: actor
  summary: "Enable developer mode, create an app/key, call the surface — three actor steps to first successful call. The capability manifest is generated from the same command/ask registry the UI uses; parity is the point (AGENTS.md non-negotiable: no agent-only mutation path)."
  status: asserted
  confidence: 0.8
}

truth developer.oauth_client {
  label: "Registered OAuth client application (id/secret, redirect URIs)"
  lifetime: account
  authority: { mode: human, ref: @actor.developer }
  visibility: [actor, staff, system]
  status: asserted
  confidence: 0.8
  metadata: { note: "Claimed observed at capability level (product contract, commit 5efb1f1); field-level shape unverified in this pass." }
}

truth developer.api_key {
  label: "Per-developer API key for the compat surface"
  lifetime: account
  authority: { mode: human, ref: @actor.developer }
  visibility: [actor, system]
  status: asserted
  confidence: 0.8
}

truth developer.capability_manifest {
  label: "Machine-readable agent capability manifest (GET /developers/agents.md)"
  lifetime: system
  authority: { mode: service, ref: @developer.compat }
  visibility: [public]
  status: asserted
  confidence: 0.85
  metadata: { note: "Product contract claims it observed: generated from the same registry the UI uses — never maintained as parallel prose (the agent_capability_manifest pattern). Verify generation source on next touch." }
}

policy manifest_generated_not_authored on @developer.capability_manifest {
  effect: require
  status: asserted
  confidence: 0.85
  rule: "The agent capability manifest is generated from the canonical command/ask registry; hand-maintaining it as parallel prose is non-conforming (one mutation path, one parity surface)."
}

policy compat_claims_bounded_by_qualification on @developer.compat {
  effect: require
  status: confirmed
  confidence: 0.95
  rule: "Parity claims for the Kiva-compat surface are bounded by @capability_qualification.kiva_api_compat: only the endpoints, fields, and flows the compat suites exercise, serving demo data. Anything beyond stays explicitly unqualified (product contract, @decision_record.compat.qualify_tested_scope)."
}

question question.developer.journey_growth on @actor.developer {
  questionType: open_question
  ask: "Grow the developer journey (stories, stages, first-person layer, key/OAuth lifecycle truths, error surfaces) from a real code read — this skeleton deliberately stops at the outcome ring."
  whyItMatters: "A skeleton that fakes depth would be hollow growth; the real journey (including agent-consumer stages) should be derived from the router, controllers, and compat tests when next touched."
  owner: "Paul Ericksen"
  neededBy: "Next substantive change to /developer, /v1, /graphql, or /oauth"
  blocking: ["Developer-facing surface changes grounded in this contract"]
  resolveWith: ["Code-read pass over the developer/compat tree + the compat test suites; practitioner gate if a real external developer is available"]
  knowledge: {
    scope: ["docs/fractalflow/developer_compat_subsystem.lssd.md depth"]
    evidence: []
    owner: "Paul Ericksen"
    learnedAt: "2026-08-10"
    invalidatedBy: ["The journey is grown from code evidence"]
    supersedes: []
  }
  status: unknown
  confidence: 0.0
}
```
