# Lender Compendium — Scope & Cast (Pass 3)

**Run:** scope = the lender plane, all sub-types · mode = **projected-from-code** ·
depth = **full** · date 2026-08-12 · Book II (Ch. 6–14) only — this run **stops at
enumeration**: no derivations, no surfaces, no prominence ranking.

**Evidence labels:** `observed` = proven in code or data · `asserted` = declared in
a contract/ruling but not built · `inferred` = reasoned, unproven.

**Method note:** the pipeline fans out one subagent per actor. This run was
executed inline by a single session at the owner's standing instruction; the
completeness critic (Pass 9) was run in fresh context via the local model hub.

---

## The 14-plane sweep, scoped to lenders

| # | Plane | Lender-plane answer |
|---|---|---|
| 1 | Visitor / anonymous | **`lender.prospective`** — intends to lend, has no account. `observed`: no registration route exists; `Accounts.register_user/1` is called only from seeds and tests. |
| 2 | Primary end user | **`lender.individual`** — role `"lender"`, 6 commands. `observed` |
| 3 | Counterparty | Borrower / partner — out of scope, but every reveal edge below names them. |
| 4 | Sub-actors / staff of an actor | **RULED OUT** — no institutional lender accounts, no delegation, no per-user roles inside a lender. One human = one lender. `observed` (no org model on `users`). |
| 5 | Operator / admin | Out of plane (audited separately 2026-08-12). |
| 6 | Support | **RULED OUT for v1** — no support actor, no ticket surface, no impersonation. A lender in trouble has no channel. `observed` |
| 7 | Finance | **RULED OUT** — no ledger, no payouts, no withdrawal. "Available to relend" is a derived figure, not an account balance. `observed` |
| 8 | Trust / safety | Partial: **`lender.encourager`** passes through moderation before reaching a borrower. `observed` |
| 9 | System / scheduler (time) | **RULED OUT AS ABSENT — and this is a finding.** No Oban, no GenServer, no cron. Nothing acts on a clock, so no expiry, digest, reminder, or sweep exists in the lender plane. `observed` |
| 10 | AI agents | **`lender.assistant_user`** — Ask Mode over their own portfolio; Command Mode can preview `complete_demo_lend`. `observed` |
| 11 | External services | Mailer (**configured, never called** — `Mailer.deliver` absent from `lib/`), LLM endpoint (optional). `observed` |
| 12 | Message recipients without accounts | **RULED OUT** — no outbound channel of any kind, so no off-platform recipient exists. `observed` |
| 13 | Future / returning selves | **`lender.returning`** and **`lender.lapsed`** — distinct stages, see ladders. `observed` (returning), `inferred` (lapsed: derivable from `available_to_relend > 0` + no recent lend, but never computed) |
| 14 | Auditor / regulator / data subject | **RULED OUT AS ABSENT — and this is a finding.** No deletion, export, or erasure path exists on `Accounts`. A lender cannot leave. `observed` |

**Cast: 8 lender actors named, 6 planes ruled out** (2 of the rule-outs are
themselves findings: no scheduler, no data-subject rights).

---

## The named lender actors

| id | Who they are | Reachable today? |
|---|---|---|
| `lender.prospective` | Wants to lend, has no account | **No exit** — cannot register (`observed`) |
| `lender.individual` | The core lender: browse, lend, relend | ✓ |
| `lender.basket_builder` | Assembles several loans, checks out once | ✓ (`Kiva.Basket` full CRUD + checkout) |
| `lender.team_founder` | Created a lending team; owns it | ✓ |
| `lender.team_member` | Lends as part of someone else's team | **UNREACHABLE** — the only `TeamMembership` insert is the owner at creation (`teams.ex:48`). No join command, no join affordance. Teams are single-person unless seeded. `observed` |
| `lender.encourager` | Writes to a borrower they backed | ✓ (moderated) |
| `lender.returning` | Comes back after an absence | ✓ but unmarked — no since-last-visit truth |
| `lender.lapsed` | Money idle, never redeployed | **Never identified** — no code computes this cohort `inferred` |
| `lender.developer` | Reads their portfolio over the API | ✓ **read-only**: neither GraphQL schema exposes a mutation; lending is impossible via API `observed` |

---

## Questions raised at cast time

- `q.cast.team_membership` — Is joining someone else's team intended? Today only
  the founder is ever a member. Owner ruling needed; it decides whether
  `lender.team_member` is an actor or a permanent rule-out.
- `q.cast.lender_exit` — Should a lender be able to delete their account and
  export their data? Plane 14 is currently absent entirely.
- `q.cast.api_write` — Should the API let a lender lend? Both schemas are
  read-only today, which makes `lender.developer` a spectator.

---

## Cast additions — folded back from critic round 1

| id | Who | State |
|---|---|---|
| `lender.assistant_user` | Lends and asks through the chat assistant | ✓ named in plane 10, **had no actor row until round 1** — now carries a ladder and stages |
| `lender.team_member` (seeded) | Belongs to a team they did not found | **Revised rule-out.** No *join path* exists, but seeded memberships do — the demo has 3 teams with members. A seeded member is a real actor with a real (thin) journey; only the *becoming* is unreachable. `observed` |
| `lender.recurring` | Auto-lends on a schedule / monthly subscription | **RULED OUT — absent.** No recurring lending, no subscription, no scheduled commitment. Real Kiva has monthly good; this product has no scheduler at all. `observed` |

**Revised cast: 11 actors, 6 planes ruled out, 1 rule-out corrected.**

## Cast addition — critic round 3

| id | Who | State |
|---|---|---|
| `lender.connected_app_user` | An ordinary lender **authorizing a third-party client** (e.g. KivaLens) against their own account — distinct from the developer who *built* it. Round 1–2 conflated the two. | ✓ reachable (`/oauth/authorize`), but **consent screen, denial path, grant review, and revocation are all absent** `observed` |
| `lender.high_volume` | Holds hundreds or thousands of lendings | ✓ exists in data (1,408 for the demo lender); **no journey is designed for it** — no search, notifications capped at 30, updates readable only one loan at a time `observed` |

**Final cast: 13 actors, 6 planes ruled out.**

## Cast addition — critic round 4

| id | Who | State |
|---|---|---|
| `external.oauth_client` | The third-party app itself (plane 11), not its human user. Holds a token against a lender's account. | ✓ exists (`/oauth/token`); **no story for token expiry, compromise, refusal, or what lender data it retains after access ends** `observed` |

**Final cast: 14 actors, 6 planes ruled out.**
