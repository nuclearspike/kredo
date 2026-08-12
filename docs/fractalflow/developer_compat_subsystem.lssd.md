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

2026-08-12: the four external boundaries are now `observed`, read from
lib/kiva_web/router.ex and lib/kiva_web/api_key_auth.ex. They had no nodes at
all — the subsystem's whole reason for existing is that it is reachable from
outside, and nothing in the graph said where the outside touches it. The
journey through those boundaries is still ungrown, so
@question.developer.journey_growth stays open and narrower: the surfaces are
mapped, the developer's story across them is not.

```lssd
model kiva.developer_compat@0.2.0 {
  namespace: "kiva.developer_compat"
  revision: "2026-08-12"
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

# --- External boundaries ------------------------------------------------
# Read from lib/kiva_web/router.ex and lib/kiva_web/api_key_auth.ex on
# 2026-08-12, so these four are observed where the rest of this skeleton is
# asserted. They partly answer @question.developer.journey_growth: the surfaces
# are now grounded, the journey through them is not.

interface compat.kiva_rest_v1 {
  label: "Legacy Kiva REST v1 (/v1) — the compatibility surface"
  status: observed
  confidence: 0.9
  governedBy: [@compat_claims_bounded_by_qualification]
  metadata: {
    mirrors: "api.kivaws.org/v1 — shape and paths replicated so an unmodified legacy client runs against Kredo",
    public_reads: ["/loans/search", "/loans/newest", "/loans/:ids", "/loans/:id/lenders", "/loans/:id/journal_entries", "/partners", "/partners/:ids", "/lenders/:ids", "/lenders/:id/loans", "/lenders/:id/teams", "/teams/search", "/teams/:ids", "/teams/:id/loans", "/templates/images"],
    authenticated_reads: ["/my/lender", "/my/loans", "/my/teams", "/my/expected_repayments" — behind :api_authenticated],
    read_only: "every route is GET; the compat surface exposes no mutation at all",
    content_negotiation: ".json/.xml suffixes stripped by KivaWeb.Plugs.KivaJsonSuffix in the endpoint before routing",
    route_order: "literal segments are declared before the /:ids catch — order is load-bearing",
    serves: "demo data only",
    verified_by: "test/kiva_web/kiva_v1/rest_test.exs"
  }
}

interface compat.kiva_graphql {
  label: "Legacy-compatible GraphQL mirror (root /graphql)"
  status: observed
  confidence: 0.9
  governedBy: [@compat_claims_bounded_by_qualification]
  metadata: {
    schema: "KivaWeb.KivaGraphql.Schema, forwarded via Absinthe.Plug",
    path: "root /graphql — deliberately the legacy path, distinct from our own /api/graphql",
    pipeline: "session + bearer + API key + locale + GraphQL context; accepts html so the GraphiQL IDE can load in a browser",
    verified_by: "test/kiva_web/kiva_graphql/schema_test.exs"
  }
}

interface compat.oauth2 {
  label: "OAuth2-compatible authorization surface (/oauth)"
  status: observed
  confidence: 0.85
  metadata: {
    mirrors: "kiva.org/oauth + api.kivaws.org/oauth/token",
    endpoints: ["GET /oauth/authorize", "POST /oauth/token"],
    issues: "bearer tokens distinct from kva_ API keys — the key plug lets non-kva_ bearers fall through to the Phoenix.Token plug untouched",
    unmodelled: "grant types, scope semantics, expiry, refresh, and revocation are not yet described here — @question.developer.journey_growth"
  }
}

interface platform.api_v2 {
  label: "Kredo's own Platform API (/api/v2)"
  status: observed
  confidence: 0.9
  metadata: {
    relationship: "bespoke and deliberately separate from the compat surfaces — not bound by @capability_qualification.kiva_api_compat",
    public: ["POST /auth/login", "GET /loans", "GET /loans/:slug", "GET /partners/:slug", "GET /teams", "GET /teams/:slug", "GET /faq"],
    authenticated: ["GET /me", "/me/loans", "/me/teams", "/me/portfolio"],
    identifiers: "slugs, not the legacy numeric ids the compat surface uses"
  }
}

truth developer.api_credential_resolution {
  label: "How a request on any external boundary is attributed to a user"
  lifetime: system
  authority: { mode: service, ref: @developer.compat }
  visibility: [system, staff]
  status: observed
  confidence: 0.9
  metadata: {
    module: "KivaWeb.ApiKeyAuth.fetch_api_key_user/2, composed before the Phoenix.Token bearer plug",
    accepts: ["Authorization: Bearer kva_…", "X-API-Key: …"],
    prefix_discipline: "the kva_ prefix is what lets OAuth/login bearers pass through untouched to the next plug",
    precedence: "an explicit valid key beats an already-assigned session user — credential over ambient cookie",
    never_halts: "an absent or invalid key leaves existing assigns alone; refusal is the job of :require_api_user on the guarded scopes, not of resolution",
    side_effect: "Developers.touch_last_used/1 on every successful key resolution"
  }
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

evaluation evaluation.compat.read_latency_at_scale {
  label: "Read latency on the external boundaries at 1.1M loans"
  dimension: performance
  subject: @compat.kiva_rest_v1
  measurements: [
    "GET /v1/loans/search.json?per_page=100, including the exact total the Kiva contract requires: 78 ms median",
    "the same page without the exact-count requirement: ~5 ms",
    "GET /v1/loans/{id}.json: 2.6 ms",
    "GET /api/v2/loans (@platform.api_v2): 3.0 ms"
  ]
  conditions: "One developer laptop, production build, Postgres on the same machine, 1,100,205 loans / 5,501,015 localized rows / 1,375,081 lendings"
  interpretation: "The legacy list endpoint is dominated by a single exact COUNT over 1.1M rows (~68 of the 78 ms); the page fetch beneath it costs a few milliseconds. Caching or estimating that total is the obvious next move and has not been done. The numbers are only this good because the default newest-first sort was sequential-scanning all 1.1M rows until an index landed during the measurement itself — 313 ms to 78 ms."
  limitations: ["One machine, one dataset, medians only — no percentile tail, no concurrency, no cold-cache runs", "Measured against generated demo data, whose distribution is not a real portfolio's", "Says nothing about the write paths or the LiveView surfaces; the lender dashboard is known to carry equivalent traps — @evidence.portfolio.dashboard_query_budget"]
  status: observed
  confidence: 0.85
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
