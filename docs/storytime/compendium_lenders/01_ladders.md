# Lender Compendium — Ladders (Pass 4)

All seven bands per actor, or a written rule-out. Band 4 (waiting) and band 7
(exit/return) get extra scrutiny — the two most-skipped.

Stage ids: `<actor>.<band>.<stage>`. `[R]` marks stages with a full record in
`02_stage_records.md`.

---

## `lender.prospective` — wants to lend, has no account

| Band | Stage | Entry → exit | State |
|---|---|---|---|
| 1 Discovery | `prospective.1.landing` **[R]** | arrives → browses or leaves | `observed` |
| 1 | `prospective.1.browsing` | on `/loans` → opens a drawer | `observed` |
| 2 Setup | `prospective.2.blocked_at_signup` **[R]** | clicks Support → **terminal** | `observed` — no registration exists |
| 3 Committing | — | **RULED OUT: unreachable.** Cannot commit without an account | `observed` |
| 4 Waiting | — | **RULED OUT: unreachable** | |
| 5 Lived event | — | **RULED OUT: unreachable** | |
| 6 Steady state | — | **RULED OUT: unreachable** | |
| 7 Exit/return | `prospective.7.silent_churn` | leaves → no trace | **no analytics event exists** `observed` |

**Four bands unreachable because band 2 is a wall.** This is the ladder of an
actor the product cannot admit.

---

## `lender.individual` — the core lender

| Band | Stage | Entry → exit | State |
|---|---|---|---|
| 1 Discovery | `individual.1.first_signin` | signs in as a seeded persona → `/loans` | `observed` |
| 2 Setup | `individual.2.no_activation` | **RULED OUT: nothing to set up.** No profile, no preferences, no payment method, no verification. A lender is fully able the instant they exist | `observed` |
| 3 Committing | `individual.3.choosing` **[R]** | browsing → opens drawer | `observed` |
| 3 | `individual.3.confirming` **[R]** | picks amount → confirms | `observed` (preview + confirm) |
| 4 **Waiting** | `individual.4.awaiting_full_funding` **[R]** | lent → loan funds, or doesn't | `observed` — reveal exists on funded |
| 4 | `individual.4.awaiting_disbursal` | funded → disbursed | `observed` |
| 4 | `individual.4.awaiting_repayment` **[R]** | disbursed → installments arrive | `observed` |
| 4 | `individual.4.loan_in_trouble` **[R]** | loan goes delinquent/defaulted | **no live path sets these states; no reveal** `observed` |
| 5 Lived event | `individual.5.fully_repaid` **[R]** | last installment → story closes | **no distinct reveal; 655 completions silent** `observed` |
| 5 | `individual.5.loss_realised` | default → principal lost | **never revealed, never summarised** `observed` |
| 6 Steady state | `individual.6.portfolio` **[R]** | returns → reviews impact | `observed` — the strongest surface |
| 6 | `individual.6.relending` **[R]** | has returned capital → redeploys | `observed` (banner) |
| 7 Exit/return | `individual.7.returning` **[R]** | absence → arrival | `observed` but unmarked |
| 7 | `individual.7.lapsing` | stops without deciding to | **not modelled** `inferred` |
| 7 | `individual.7.leaving` | wants out | **RULED OUT AS ABSENT** — no deletion/export `observed` |

---

## `lender.basket_builder`

| Band | Stage | Notes |
|---|---|---|
| 1–2 | inherits `lender.individual` | |
| 3 | `basket.3.assembling` **[R]** | add/remove/clear across loans `observed` |
| 3 | `basket.3.checkout` **[R]** | one act, many loans → many `Lend` rows `observed` |
| 4 | inherits per-loan waiting stages | one basket fans into N independent waits — **no basket-level view after checkout** `observed` |
| 5–6 | inherits | |
| 7 | `basket.7.abandoned` | **RULED OUT AS UNMODELLED** — items persist forever, no reminder, no sweep, no expiry (no scheduler) `observed` |

---

## `lender.team_founder`

| Band | Stage | Notes |
|---|---|---|
| 1 | `team.1.discovering_teams` | `/teams` browse `observed` |
| 2 | `team.2.creating` **[R]** | name + visibility → team exists, founder is sole member `observed` |
| 3 | `team.3.lending_on_behalf` **[R]** | picks team at lend time `observed` |
| 4 | `team.4.awaiting_others` | **hollow band** — nobody else can join, so there is nothing to await `observed` |
| 5 | `team.5.team_impact` | team total updates `observed` |
| 6 | `team.6.message_board` | posts, on-demand translation `observed` |
| 7 | `team.7.disband` | **RULED OUT AS ABSENT** — no delete/archive/transfer of a team `observed` |

---

## `lender.encourager`

| Band | Stage | Notes |
|---|---|---|
| 3 | `encourager.3.writing` **[R]** | composes to a borrower they backed `observed` |
| 4 | `encourager.4.awaiting_moderation` **[R]** | submitted → approved/blocked/rewrite-suggested `observed` |
| 5 | `encourager.5.delivered` | **the sender is never told the outcome** `observed` |
| 5 | `encourager.5.reply` | **RULED OUT AS ABSENT** — borrowers cannot reply `observed` |
| 7 | — | n/a |

---

## `lender.returning` / `lender.lapsed`

| Band | Stage | Notes |
|---|---|---|
| 7 | `returning.7.arrival` **[R]** | comes back → **nothing marks the interval** `observed` |
| 7 | `returning.7.stale_truths` | prices/status changed since last visit — **never re-revealed** (storm S12) `observed` |
| 7 | `lapsed.7.dormant` | capital idle, no nudge — **cohort never computed, and no channel to reach them if it were** `inferred` |

---

## `lender.developer`

| Band | Stage | Notes |
|---|---|---|
| 2 | `developer.2.enabling` | self-serve capability + API key `observed` |
| 3 | `developer.3.reading` | `/api/v2/me/*`, `/v1/my/*`, GraphQL `my` `observed` |
| 3 | `developer.3.cannot_write` | **terminal** — no mutation exists in either schema `observed` |
| 7 | `developer.7.key_rotation` | **not modelled** `inferred` |

---

**Ladders: 9 actors · 38 stages · 13 bands ruled out in writing** (0 silent).
Of the 13 rule-outs, **7 are "absent and that is a finding"** rather than "not
applicable": prospective bands 3–6, basket abandonment, team disband, encourager
reply, lender exit.

---

## Ladder additions — folded back from critic round 1

### `lender.assistant_user`
| Band | Stage | Notes |
|---|---|---|
| 1 | `assistant.1.discovering` | FAB present on every page (restored 2026-08-11) `observed` |
| 3 | `assistant.3.asking` | Ask Mode → role-scoped GraphQL `observed` |
| 3 | `assistant.3.previewing_a_lend` **[R]** | Command Mode builds a preview; **never mutates directly** `observed` |
| 4 | `assistant.4.awaiting_confirm` | preview shown → confirm or abandon `observed` |
| 7 | `assistant.7.conversation_persists` | transcript retained forever, **readable by all staff**, never disclosed `observed` |

### `lender.team_member` (seeded)
| Band | Stage | Notes |
|---|---|---|
| 2 | `member.2.becoming` | **UNREACHABLE** — no join path `observed` |
| 6 | `member.6.reading_board` | reads posts, on-demand translation `observed` |
| 6 | `member.6.posting` | `post_team_message` `observed` |
| 7 | `member.7.leaving` | **ABSENT** — no leave, no removal `observed` |

### Stages missing from `lender.individual` (critic hits 5, 6, 7)
| Band | Stage | Notes |
|---|---|---|
| 3 | `individual.3.receipt` **[R]** | immediately post-lend: "Thank you for lending / You moved / View my impact" `observed` — a real beat that had no row |
| 4 | `individual.4.deadline_passed` **[R]** | the loan they backed never funded and its deadline expired — **terminal, unmodelled**; 3,989 loans sit here `observed` |
| 5 | `individual.5.partial_return` **[R]** | an installment lands; principal becomes relendable — the *recurring* lived event, distinct from full repayment `observed` |

**Revised ladders: 11 actors · 47 stages · 15 written band rule-outs.**

---

## Ladder additions — folded back from critic round 2

### `lender.team_member` (seeded), completed
| Band | Stage | Notes |
|---|---|---|
| 3 | `member.3.lending_on_behalf` | same command as the founder; **membership not verified at lend time** `observed` |
| 5 | `member.5.team_impact` | the team total moves; **no member is told** (R10) `observed` |

### `lender.assistant_user`, failure band
| Band | Stage | Notes |
|---|---|---|
| 4 | `assistant.4.model_unavailable` **[R]** | no model configured, or the endpoint fails | since 2026-08-11 the assistant **says how to connect one**; before that it degraded silently `observed` |
| 4 | `assistant.4.tool_refused` | a role-scoped GraphQL query or command preview is denied | the refusal is recorded as a tool call and **shown to the lender**; the admin inspector can reconstruct it `observed` |

### `lender.developer`, activation band
| Band | Stage | Notes |
|---|---|---|
| 2 | `developer.2.registering_an_app` | OAuth client + secret issued, self-serve `observed` |
| 3 | `developer.3.authorizing` | `/oauth/authorize` → token; **demo-grade, stateless** `observed` |
| 7 | `developer.7.revoking` | **ABSENT** — no revoke for key, app, or token `observed` |

### `lender.individual`, receiving news
| Band | Stage | Notes |
|---|---|---|
| 5 | `individual.5.reading_an_update` **[R]** | a borrower they backed posted an update | notified (R4) ✓, but readable **only on that loan's page** — no feed `observed` |

**Revised ladders: 11 actors · 56 stages · 16 written band rule-outs.**

## Ladder additions — critic round 3

### `lender.connected_app_user`
| Band | Stage | Notes |
|---|---|---|
| 2 | `connected.2.authorizing` **[R]** | `/oauth/authorize` → token | **no consent screen enumerated**; what the app may see is never shown to the lender `observed` |
| 2 | `connected.2.denying` | declining the grant | **no path** `observed` |
| 6 | `connected.6.reviewing_grants` | "which apps can see my data?" | **no surface** `observed` |
| 7 | `connected.7.revoking` | withdrawing access | **no path** `observed` |

### `lender.individual`, additions
| Band | Stage | Notes |
|---|---|---|
| 1 | `individual.1.reauthenticating` **[R]** | signed-out, following a deep link or interrupted mid-commitment | `:user_return_to` is written **and never read**, so they land on `/loans` having lost their place `observed` |
| 6 | `individual.6.notification_triage` | facing the pile | one decision only: `mark_all_read` — no per-item dismiss, no filter, no grouping `observed` |

### `lender.high_volume`
| Band | Stage | Notes |
|---|---|---|
| 6 | `high_volume.6.finding_one` | "where's that Jordanian tailor?" | **no text search across 1,408 lendings** `observed` |
| 6 | `high_volume.6.notification_history` | older than the most recent 30 | **unreachable — hard cap, no pagination** `observed` |

**Final ladders: 13 actors · 63 stages · 18 written band rule-outs.**

## Ladder additions — critic round 4

### `external.oauth_client` (plane 11)
| Band | Stage | Notes |
|---|---|---|
| 2 | `client.2.obtaining_token` | `/oauth/token`, demo-grade + stateless `observed` |
| 3 | `client.3.reading_as_lender` | acts with the lender's read scope `observed` |
| 4 | `client.4.token_expiry` | **not modelled** — stateless tokens, no expiry story `observed` |
| 7 | `client.7.compromised_or_retired` | **no revocation, no retention rule for lender data it already pulled** `observed` |

### `lender.assistant_user`, the failure the enumeration missed
| Band | Stage | Notes |
|---|---|---|
| 4 | `assistant.4.incorrect_answer` **[R]** | the model answers plausibly and **wrongly** about the lender's own money | **no correction path, no provenance on the answer, no feedback affordance, no recovery.** Outages and refusals were enumerated; being *confidently wrong* was not `observed` |

### `lender.team_member`, private teams
| Band | Stage | Notes |
|---|---|---|
| 1 | `member.1.finding_a_private_team` | visibility accepts `public / private / invite_only` | **discovery, read eligibility, post eligibility, and denial behaviour for non-public teams are enumerated nowhere** — and `invite_only` has no invite mechanism at all `observed` |

**Final ladders: 14 actors · 67 stages · 19 written band rule-outs.**
