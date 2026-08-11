# Kiva-Like Multilingual Chat-First Demo — LSSD Planning Bundle

Created: 2026-06-26

This bundle is a planning and implementation-guide deliverable for a coding agent. It intentionally does **not** set up Phoenix, Ecto, LiveView, Postgres, GraphQL, or any external service. It defines the product architecture, domain model, localization model, AI-chat boundaries, FractalFlow seed docs, command registry, GraphQL surfaces, demo data, test plan, and staged implementation path.

The working name inside the bundle is **Kiva Future Demo**. It is a Kiva-like concept intended as a proposal/demo system, not an official Kiva product unless Kiva adopts it.

## Start here

1. Read `00_product_vision_prd.md`.
2. Read `01_agent_handoff_lssd.md`.
3. Read `02_system_tree_and_subsystems.md`.
4. Read the FractalFlow seed files under `fractalflow/`.
5. Use `schemas/command_registry.yaml`, `schemas/database_model.yaml`, and `schemas/graphql_surface_map.yaml` as the first implementation contracts.
6. Use `17_acceptance_tests_and_story_specs.md` as the test spine.

## Bundle structure

- `00_product_vision_prd.md` — product vision, demo scope, actors, outcomes, non-goals.
- `01_agent_handoff_lssd.md` — how a coding agent should work in bounded LSSD passes.
- `02_system_tree_and_subsystems.md` — LSSD tree and subsystem branch map.
- `03_data_model_and_localization.md` — canonical tables, `*_lc` language content sidecars, fallback, translation lifecycle.
- `04_ai_chat_first_architecture.md` — page-aware chat, Ask Mode, Command Mode, tool boundaries, GraphQL surfaces.
- `05_graphql_surfaces_and_api_contracts.md` — public/lender/borrower/partner/staff/admin schemas.
- `06_permissions_trust_and_risk.md` — RBAC/ABAC, permission groups, outlier analysis, trust networks.
- `07_storytime_actor_stage_specs.md` — borrower/lender/partner/admin actor stages and affordances.
- `08_partner_chat_loan_application.md` — partner chat-first loan application flow.
- `09_lender_discovery_teams_messages.md` — lender discovery, lending teams, message boards, encouragement messages.
- `10_borrower_portal_native_language.md` — borrower portal, translated loan details, Android/internet-cafe access.
- `11_admin_staff_and_translation_ops.md` — admin, review, translation, moderation, dashboards.
- `12_trust_networks_blockchain_and_alternative_underwriting.md` — trustees, endorsements, alternative checks, blockchain attestations.
- `13_analytics_distribution_graphs.md` — graphs and data views for team/lender/partner/portfolio distributions.
- `14_demo_seed_data.md` — demo accounts, fake partners, borrowers, loans, teams, messages.
- `15_roadmap_and_work_packages.md` — staged build plan and coding-agent work packages.
- `16_cool_expansion_ideas.md` — extra ideas that make the demo sing instead of merely breathe.
- `17_acceptance_tests_and_story_specs.md` — acceptance criteria and test categories.
- `fractalflow/*.lssd.md` — canonical seed model docs.
- `schemas/*.yaml` — data, GraphQL, command, translation, analytics contracts.
- `prompts/*.md` — master coding-agent prompt and AI bot prompt templates.
- `source_notes.md` — public source notes and design anchors.

## Core decision

Use **Postgres as the primary persistence layer**. Do not introduce MongoDB for v1. Postgres is enough for canonical relational truth, localization sidecars, full-text search, JSONB metadata, materialized read models, pg_trgm search, and pgvector-style semantic retrieval if the implementation wants embeddings later. MongoDB can be reconsidered only if localized read models become heavy enough to justify a document-read layer.

## Non-negotiables

- Multilingual is not a feature. It is infrastructure.
- Every major content entity has a language-content sidecar table.
- Every actor-facing page can switch language via globe dropdown.
- Every page has page-aware chat.
- Chat asks and explains through scoped GraphQL. It mutates only through a command registry.
- Admin chat uses a separate staff/admin GraphQL schema surface.
- AI never bypasses permissions, policies, moderation, or review states.
- Fake/demo data only. No real loans, no real payment processing, no real borrower PII.
