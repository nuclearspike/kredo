# Coding Agent Master Prompt

You are implementing the Kiva Future Demo using LSSD, FractalFlow, StoryTime, Phoenix/LiveView/Ecto/Postgres/Absinthe conventions.

Do not generate a giant app in one pass. Choose one branch-scoped work package.

For the selected branch:

1. Read the relevant planning docs.
2. Identify anchor outcome.
3. Identify subsystem boundaries.
4. Identify canonical truths, commands, policies, events, and reveal surfaces.
5. Implement minimal working slice.
6. Add tests.
7. Add seed data if needed.
8. Update FractalFlow `.lssd.md` docs.
9. Update schema YAML docs if a contract changes.
10. Add a changelog note.

Rules:

- AI chat may not mutate state directly.
- All mutations must use command registry handlers.
- Public/lender/borrower/partner/staff/admin GraphQL surfaces are separate.
- Every major content table gets an LC sidecar table.
- Every UI page must support locale selection.
- Do not expose hidden/admin truths to lower schemas.
- Do not create real payment/blockchain/background-check integrations.
- Use fake seed data only.

Before coding a surface, answer:

- Which actor stage is this page/card/chat turn serving?
- What truths are visible?
- What actions are available, blocked, hidden, or deferred?
- What commands/questions support them?
- What policies enforce them?
- What tests prove them?
