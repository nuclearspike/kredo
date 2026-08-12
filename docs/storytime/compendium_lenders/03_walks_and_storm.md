# Lender Compendium — Consequence Walks (Pass 6) & Scenario Storm (Pass 7)

## Part A — Consequence walks

One walk per available decision that mutates. Format: command → eligibility →
effects → reveals (in the **recipient's** locale) → failure modes.

| # | Decision | Command | Eligibility (server) | Effects | Reveals | Failure modes |
|---|---|---|---|---|---|---|
| W1 | Lend now | `complete_demo_lend` | `loan_fundraising`, `lend_amount_valid` | `Lend` row; loan funded% up; snapped to $25 units | loan public %; **lenders only if it crosses to fully funded**; borrower **none** | not fundraising → typed refusal; off-unit amount → typed refusal |
| W2 | Add to basket | `add_loan_to_basket` | `loan_fundraising`, `lend_amount_valid` | `Item` row | **none** | same as W1 |
| W3 | Remove / clear basket | *(context fn — **no registry entry**)* | none | rows deleted | none | **command-coverage gap** `observed` |
| W4 | Checkout basket | `Basket.checkout/1` *(**no registry entry**)* | per-item at lend time | N × `Lend`; basket cleared | per-loan as W1 | **partial failure across items unmodelled**; **command-coverage gap** `observed` |
| W5 | Create team | `create_lending_team` | `team_visibility_valid` | `Team` + owner `TeamMembership` | none | invalid visibility → typed refusal |
| W6 | Lend on behalf of team | `complete_demo_lend` (+`team_id`) | team must **exist** — membership **not checked** | `Lend.lending_team_id`; team total | team members **none** | **eligibility gap** `observed` |
| W7 | Post to team board | `post_team_message` | `team_exists` | `TeamPost` + source LC | on-demand translation to readers | none |
| W8 | Encourage a borrower | `submit_encouragement_message` | `loan_exists` — **backing not required** | message + moderation verdict + translation | borrower **if approved**; sender **never** | blocked/flagged → held, sender not told |
| W9 | Switch language | `set_locale` | `locale_supported` | session + user default | none | unsupported → typed refusal |
| W10 | Relend | *(navigation, not a command)* | — | — | — | intent carries no state to the destination |
| W11 | Delete account / export | **NO COMMAND** | — | — | — | plane 14 absent |
| W12 | Cancel a lending | **NO COMMAND** | — | — | — | irreversible by absence, not by policy |

**Walks: 12 · commands 8 · registry gaps 3 (W3, W4 outside the registry; W10 not a command) · absent-by-design-unstated 2 (W11, W12).**

---

## Part B — Scenario storm (14 families × the lender plane)

| # | Family | Yield for lenders | State |
|---|---|---|---|
| S1 | Abandonment mid-creation | Basket persists forever; no reminder, no sweep, no expiry — **no scheduler exists**. Abandoned baskets are invisible to analytics. | `observed` gap |
| S2 | Rejection / decline | An encouragement blocked by moderation: borrower unaffected, **sender never told, reason withheld** — plausibly deliberate, nowhere written. | `observed` gap |
| S3 | Expiry / timeout | A loan the lender backed never funds: **no expiry state, no reveal, no refund concept.** 3,989 loans past deadline. The lender's money is notionally committed to a campaign that ended. | `observed` **major** |
| S4 | Cancellation before commitment | Removing a basket item — works, unregistered, unrevealed. | `observed` minor |
| S5 | Cancellation after commitment | **No path.** A lending cannot be withdrawn; nothing says so. | `observed` gap |
| S6 | Change after commitment | Cannot change amount or team attribution after lending. Unstated. | `observed` gap |
| S7 | Concurrent collision | `Portfolio.lend/4` is a read-modify-write with no row lock. Over-funding is **prevented** by a `min()` cap (I claimed otherwise and was wrong — see below). What is not prevented is divergence between the loan's funding figure and the sum of its lendings. | `observed` **major** |
| S8 | Partial / external failure | Basket checkout partially failing is unmodelled. No external service participates in lending (no processor), so the blast radius is small. | `inferred` |
| S9 | Refund / reversal / dispute | **Entirely absent.** No refund, no reversal, no dispute, no ledger. Consistent with "demo, no real money" — but nowhere written as an exclusion. | `observed` |
| S10 | No-response / ghosting | The borrower never posts an update; the partner never records repayment. **No nudge, no escalation, no default resolution** — the lender simply waits forever. | `observed` gap |
| S11 | First-run / empty state | ✓ **Handled well** — the empty portfolio is a warm invitation, not a dashboard of zeros. | `observed` **strength** |
| S12 | Returning after absence | Stale truths (a backed loan now defaulted; a team gone quiet) are **never re-revealed**. No since-marker. | `observed` gap |
| S13 | Admin intervention | Staff approve/reject translations and moderate messages on loans the lender backed. **The lender is never told a listing they funded was altered.** | `observed` gap |
| S14 | Deletion / retention | No deletion. If it existed: their `Lend` rows are half of a borrower's funding history and cannot simply vanish — **the hardest unasked question in the plane.** | `observed` **major** |

**Storm yield: 14 families run · 11 gaps · 1 strength · 3 majors (S3, S7, S14) ·
2 folded back into ladders as new stages** (`individual.4.loan_in_trouble`,
`basket.7.abandoned`).

A storm that yields nothing wasn't run; this one moved two stages and produced
the over-funding race below.

---

### S7, expanded — funding truth diverges from lending truth

**First claim, withdrawn.** I asserted that concurrent lends could push a loan
over its own amount. That is false: `Portfolio.lend/4` computes
`new_funded = min(loan_amount_cents, funded + amount)`, so the total is capped.
Verified: **0 over-funded loans** in 1.1M.

**What the data actually shows**, from the same query:

| Check | Count |
|---|---|
| Loans where `sum(lendings) > funded_amount_cents` | **7,219** |
| Loans where `sum(lendings) > loan_amount_cents` | **6,268** |
| Loans where `funded_amount_cents > loan_amount_cents` | 0 |

Two truths about the same money disagree. The **loan's** funding bar reads
`funded_amount_cents`; the **lender's** portfolio is derived from `lendings`. For
7,219 loans a lender's recorded contribution is not reflected in what the
borrower's page shows as raised — and for 6,268, lenders collectively put in
more than the loan ever needed.

The cause is most plausibly generated data rather than a live race (this demo has
one concurrent user, and the `min()` cap plus the read-modify-write together
*produce* exactly this shape whenever funding is written from two directions —
`simulate_funding` sets the figure without creating lendings, while the generator
wrote both independently). **The finding is not "a race happened"; it is that
nothing in the system could ever tell.** There is no invariant, no constraint, no
reconciliation, and no test relating these two numbers, so the divergence is
silent and permanent. Law 7/8: a detail whose confidence nobody checks.

`observed` (the divergence) · `inferred` (the mechanism)

---

## Walk additions — folded back from critic round 1

| # | Decision | Command | State |
|---|---|---|---|
| W13 | Edit a basket item's amount | `Basket.add/3` re-add overwrites | **unregistered**, no UI affordance to change an amount `observed` |
| W14 | Recover a stale basket item | — | **no path**: a loan that left fundraising sits in the basket and fails only at checkout `observed` |
| W15 | Invite / join a team | — | **NO COMMAND** `observed` |
| W16 | Leave a team / remove a member | — | **NO COMMAND** `observed` |
| W17 | Transfer team ownership | — | **NO COMMAND** — a founder is permanent `observed` |
| W18 | Edit / delete a team post | — | **NO COMMAND** — posts are immutable and undeletable `observed` |
| W19 | Rotate / revoke an API key | `Developers.upsert_api_key` exists; **no revoke** | key is permanent once issued `observed` |
| W20 | Preview a lend via the assistant | `complete_demo_lend` (preview → confirm) | ✓ **same command as the button — agent parity holds on the read/preview side** `observed` |

**Revised walks: 20 · commands 9 · absent-by-omission 6 (W15–W19, W12).**

---

## Walk additions — folded back from critic round 2

| # | Decision | Command | State |
|---|---|---|---|
| W21 | Edit a founded team's name or visibility | — | **NO COMMAND** — a team is immutable after creation `observed` |
| W22 | Edit or withdraw an encouragement awaiting moderation | — | **NO COMMAND** — once submitted it is out of the sender's hands, and they are never told its fate `observed` |
| W23 | Register an OAuth app / issue an API key | `Developers.upsert_app` / `upsert_api_key` | **outside the command registry** — self-serve context calls `observed` |
| W24 | Read a borrower update | *(read-only)* | reachable only from the loan page `observed` |

**Revised walks: 24 · registry gaps 5 (W3, W4, W13, W23, and W10-as-navigation).**

## Walk additions — critic round 3

| # | Decision | Command | State |
|---|---|---|---|
| W25 | Authorize a third-party app | `OauthController.authorize` | **no consent enumeration, no scope display, no denial path** `observed` |
| W26 | Revoke an app's access | — | **NO COMMAND** `observed` |
| W27 | Mark all notifications read | `Notifications.mark_all_read/1` | **outside the command registry**; no per-item dismiss `observed` |
| W28 | Ask the assistant a question | `Kiva.AI.Assistant.respond/2` | creates `AIConversation` + `Message` + `ToolCall` artifacts; **outside the command registry** (correct — it is a read), but the artifacts it creates have no retention story `observed` |

**Final walks: 28 · registry gaps 8.**

### Correction — the `loan_outcome` channel

Critic round 3 called `loan_outcome` an orphaned notification type. **Partly
wrong:** it is produced by `Updates.post_update/5` with `kind: "outcome"`
(partner/staff/admin). The accurate finding is sharper: the outcome channel
exists and is **never fired by the two events that actually constitute a
lender's outcome** — full repayment emits the generic `repayment` string, and
loss emits nothing at all. Outcome truth (L37) has a delivery mechanism and no
producer for the outcomes that matter. `observed`
