# Planning Corpus — what was specified before any code existed

Eighteen documents, about 10,000 words, written **before** Kredo was built. They
are the input the build was driven from: the product vision, the subsystem
breakdown, the data and localization architecture, the API contracts, the actor
specs, and a roadmap of work packages.

They are preserved unedited as a historical record. **They are not current.**

> **Read these as an artifact, not a reference.** They predate a late rename and
> still call the product "Kiva Future Demo". Where they disagree with the code,
> the code and the [contracts](../fractalflow/) win. Where they describe
> something that was never built, that is worth noticing — several audit findings
> in [`../storytime/`](../storytime/) are exactly the distance between what these
> documents promised and what exists.

**Related:** [`../fractalflow/`](../fractalflow/) — the living contracts that
superseded these · [`../storytime/`](../storytime/) — audits of what actually got
built, and a glossary of the methodology's vocabulary.

---

## Why they are interesting

This is the **spec-from-scratch** mode of LSSD, and the whole corpus was
AI-generated from a product idea before implementation began. Reading it beside
the audits shows the full arc of the experiment:

**planned → built in ~8.6 hours → audited → gaps found.**

A few things are visible here that are invisible anywhere else:

- Document `07` specifies actor stages **before** there were screens — the
  ancestor of the StoryTime audits, at a much lower resolution.
- Document `16` is a list of expansion ideas, most of which were never built. It
  is a fair test of how much of an AI-written plan survives contact with an
  AI-written implementation.
- Document `17` defines acceptance tests as story specs. The suite that exists
  today (309 tests) grew from these, and the audits later demonstrated what that
  kind of test cannot catch.

---

## The documents

### Foundations
| # | Document | What it covers |
|---|---|---|
| 00 | [Product Vision PRD](00_product_vision_prd.md) | The premise, the actors, and what the product is for |
| 01 | [Coding Agent Handoff — LSSD Operating Guide](01_agent_handoff_lssd.md) | The instructions the building agent worked under |
| 02 | [System Tree and Subsystems](02_system_tree_and_subsystems.md) | The decomposition the contracts later inherited |

### Architecture
| # | Document | What it covers |
|---|---|---|
| 03 | [Data Model and Localization](03_data_model_and_localization.md) | Sidecar rows for every content entity — the decision that made five languages structural rather than a translation pass |
| 04 | [AI Chat-First Architecture](04_ai_chat_first_architecture.md) | Ask Mode, Command Mode, and the rule that the assistant may propose but never mutate |
| 05 | [GraphQL Surfaces and API Contracts](05_graphql_surfaces_and_api_contracts.md) | The role-scoped schema and the API surfaces |
| 06 | [Permissions, Trust, and Risk](06_permissions_trust_and_risk.md) | Permission groups, trust models, and risk display |

### Actor journeys
| # | Document | What it covers |
|---|---|---|
| 07 | [StoryTime Actor Stage Specs](07_storytime_actor_stage_specs.md) | First-pass actor stages — compare with `../storytime/` to see what the method looks like at full resolution |
| 08 | [Partner Chat-First Loan Application](08_partner_chat_loan_application.md) | The guided application flow. **Largely unbuilt** — see the partner audit |
| 09 | [Lender Discovery, Teams, and Messages](09_lender_discovery_teams_messages.md) | Browsing, lending, teams, encouragement |
| 10 | [Borrower Portal and Native-Language Access](10_borrower_portal_native_language.md) | The borrower's view in their own language |
| 11 | [Admin, Staff, Review, Translation, Moderation Ops](11_admin_staff_and_translation_ops.md) | The operational queues |

### Distinctive features
| # | Document | What it covers |
|---|---|---|
| 12 | [Trust Networks, Blockchain, Alternative Underwriting](12_trust_networks_blockchain_and_alternative_underwriting.md) | Trustees, endorsements, and mock attestations |
| 13 | [Analytics and Distribution Graphs](13_analytics_distribution_graphs.md) | The distribution views on the admin surface |
| 14 | [Demo Seed Data](14_demo_seed_data.md) | The seeded world — ancestor of today's `scripts/loan_gen/` generator |

### Delivery
| # | Document | What it covers |
|---|---|---|
| 15 | [Roadmap and Coding Agent Work Packages](15_roadmap_and_work_packages.md) | How the build was sliced into agent-sized units |
| 16 | [Expansion Ideas Worth Stealing From The Future](16_cool_expansion_ideas.md) | Ideas beyond v1, mostly unbuilt |
| 17 | [Acceptance Tests and Story Specs](17_acceptance_tests_and_story_specs.md) | Tests defined as stories rather than assertions |

---

Also from this era, one directory up:
[`../../README_PLANNING.md`](../../README_PLANNING.md) (the original bundle
README) and [`../../IMPLEMENTATION_LOG.md`](../../IMPLEMENTATION_LOG.md) (the
per-phase build log recording what was observed versus asserted at each step).
