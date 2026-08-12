# Lender Compendium — Matrices, Counts, Gates, Questions (Pass 9 close-out)

## Matrices

**M1 — actor × band coverage** (● full record · ○ ladder row · — ruled out)

| Actor | B1 | B2 | B3 | B4 | B5 | B6 | B7 |
|---|---|---|---|---|---|---|---|
| `lender.prospective` | ● | ● | — | — | — | — | ○ |
| `lender.individual` | ● | — | ● | ● | ● | ● | ● |
| `lender.basket_builder` | ○ | ○ | ● | ○ | ○ | ○ | — |
| `lender.team_founder` | ○ | ● | ● | ○ | ○ | ○ | — |
| `lender.team_member` | — | — | ○ | — | ○ | ○ | — |
| `lender.encourager` | — | — | ● | ● | ○ | — | — |
| `lender.returning` | — | — | — | — | — | — | ● |
| `lender.lapsed` | — | — | — | — | — | — | ○ |
| `lender.developer` | — | ○ | ● | — | — | — | ○ |
| `lender.assistant_user` | ○ | — | ● | ● | — | — | ○ |
| `lender.connected_app_user` | — | ● | — | — | — | ○ | ○ |
| `lender.high_volume` | — | — | — | — | — | ○ | — |

**M2 — decision × command coverage:** 28 walks · 9 registered commands ·
**8 mutating paths outside the registry** (basket remove/clear/checkout/edit,
mark-all-read, API key + OAuth app issuance, team creation side-effects) ·
**7 decisions with no command at all** (cancel a lending, join/leave/transfer a
team, edit a team, edit/withdraw an encouragement, revoke app access, delete
account).

**M3 — transition × reveal:** 13 edges · 4 implemented · **9 unwritten silences ·
0 written silences.**

**M4 — artifact × deletion path:** 15 artifacts · **0 with a deletion path.**

**M5 — scenario × lender:** 14 storm families · 11 gaps · 3 majors (S3 expiry,
S7 funding-truth divergence, S14 deletion) · 1 strength (S11 empty state).

---

## §14.3 count block

```
LENDER PLANE — Book II enumeration, projected-from-code, 2026-08-12

cast .................. 14 actors · 6 planes ruled out (2 rule-outs are findings)
ladders ............... 67 stages · 19 bands ruled out in writing · 0 silent
stage records ......... 18 full (first-person block + 6 decision categories)
                        45 ladder rows awaiting full records      << PARTIAL
question stacks ....... 18 (= full stage records, L83)
consequence walks ..... 28 · 9 registered commands
reveal edges .......... 13 · implemented 4 · unwritten silences 9 · written 0
communication ......... in-app 5 templates · email 0 · SMS/push 0 · digest 0
artifact stories ...... 15 · deletion paths 0
detail stories ........ 13 · unresolved confidence 5
storm ................. 14 families · 11 gaps · 3 majors · 2 stages folded back
                        1 claim raised and WITHDRAWN on evidence (S7 over-funding)
critic ................ r1: 10 hits · r2: 8 · r3: 6 (1 partly wrong) · r4: 3
                        NEVER REACHED TWO DRY ROUNDS -- bounded stop at r4  << PARTIAL
                        yield decaying 10>8>6>3; all 27 hits folded back
open questions ........ 19
```

---

## Gate report (Book II, G1–G6)

| Gate | Status | Basis |
|---|---|---|
| **G1** cast complete | ✅ PASS | 14 planes swept; 13 actors named, 6 rule-outs written |
| **G2** ladders, all 7 bands | ✅ PASS | 63 stages; 18 bands ruled out **in writing**; 0 silent |
| **G3** stage records + first-person | ⚠️ **PARTIAL — declared, not claimed** | 18 of 63 stages (29%) carry a full record. The 18 cover every named actor's pivotal stage and every band that exists, but **45 stages are ladder rows only**. Depth was declared `full`; on this gate the run delivered less. Closing it means 45 more records. |
| **G4** walks 1:1 with decisions | ✅ PASS | every mutating decision walked; 8 registry gaps + 7 absent commands recorded as findings rather than skipped |
| **G5** storm folded back | ✅ PASS | 14 families; yielded 2 new stages and 1 withdrawn claim — a storm that moved the enumeration |
| **G6** reveals + artifacts + details | ✅ PASS | 13 edges, 15 artifacts, 13 details, all with state labels |
| **critic** two consecutive dry rounds | ⚠️ **NOT MET — bounded stop** | 4 rounds run in fresh context via the hub; hits 10 → 8 → 6 → 3, all folded back. The skill bounds the loop at 4 rounds rather than looping unbounded, so this run **stops with the critic still yielding**. A 5th round would likely yield 1–3 more. |

**This run stops at enumeration.** G7–G9, journey optimization (prominence,
presets, adaptive actions), derivations, and surfaces belong to the pipeline
(lssd-guide Pass 10+), not here.

---

## Open questions, grouped by decision type

**Product policy — the owner must rule (10)**
1. Is joining someone else's team intended? Today only a founder is ever a member.
2. Should a lender be able to delete their account and export their data? (Plane 14 absent.)
3. Should the API allow lending, or is read-only deliberate? (Makes `lender.developer` a spectator.)
4. Is recurring / auto-lending in scope? (Ruled out as absent; real Kiva has it.)
5. Should a lending be cancellable before the loan funds? (No path; nothing says so.)
6. What happens to a lender's money when a backed loan never funds? (3,989 loans; no refund concept.)
7. Should a borrower learn that an individual lent, or only aggregate funding?
8. Should an encouragement sender learn their message was delivered — or blocked, and why?
9. Should teams support invite / leave / transfer / disband, or stay founder-only artifacts?
10. Should a lender see and revoke which third-party apps can read their account?

**Data / truth integrity — needs a ruling then a fix (3)**
11. `funded_amount_cents` disagrees with `sum(lendings)` on **7,219 loans**. Which is authoritative, and should they be reconciled or constrained?
12. `available_to_relend_cents` is presented as money but derived from a capped estimate with no ledger. Is that acceptable framing?
13. Should notification history beyond the most recent 30 be reachable?

**Product policy — added by critic round 4 (3)**
17. Should a lender be able to see, refuse, and revoke a third-party app's token — and what happens to lender data the app already pulled?
18. What is the recovery path when the assistant answers a money question plausibly and wrongly? (No correction, provenance, or feedback affordance exists.)
19. What do `private` and `invite_only` teams actually mean? Visibility is settable and `invite_only` has no invite mechanism.

**Architecture — blocks several stories (3)**
14. There is **no scheduler of any kind**. Expiry, digests, reminders, sweeps, and the lapsed-lender cohort all depend on one existing. Is that in scope?
15. There is **no outbound channel**. Every reveal is pull-only. Is in-app-only deliberate?
16. Should `Portfolio.lend/4`'s read-modify-write be transactional, given the divergence in Q11?
