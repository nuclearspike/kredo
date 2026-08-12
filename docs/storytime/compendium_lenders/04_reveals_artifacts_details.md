# Lender Compendium — Reveal Edges, Communication Catalog, Artifact & Detail Stories (Pass 8)

## Part A — Reveal edges (M3)

Every committed transition either reveals to a named actor or carries a written
silence. `→ ∅` means **no reveal and no written decision** — the trust-killer.

| # | Truth crossing | From | To | Channel | Locale | State |
|---|---|---|---|---|---|---|
| R1 | Loan reached 100% | lender's lend | **all lenders of that loan** | in-app | recipient's | `observed` ✓ |
| R2 | Funds disbursed | partner | all lenders | in-app | recipient's | `observed` ✓ |
| R3 | Repayment recorded | partner | all lenders | in-app | recipient's | `observed` ✓ **but anonymous** — no borrower, no amount |
| R4 | Borrower posted an update | borrower/partner | all lenders | in-app | recipient's | `observed` ✓ |
| R5 | Loan fully repaid | system | all lenders | — | — | **→ ∅** no distinct reveal; 655 completions silent |
| R6 | Loan went delinquent / defaulted | — | all lenders | — | — | **→ ∅** no live path even sets the state |
| R7 | A lender lent | lender | **borrower** | — | — | **→ ∅** *(defensible: individual lends may be private — but unwritten)* |
| R8 | Encouragement approved & delivered | staff | **sender** | — | — | **→ ∅** |
| R9 | Encouragement blocked | staff | sender | — | — | **→ ∅** reason withheld, unwritten |
| R10 | Team total changed | a member's lend | other team members | — | — | **→ ∅** |
| R11 | Listing altered by staff after funding | staff | lenders of that loan | — | — | **→ ∅** (storm S13) |
| R12 | Basket item's loan left fundraising | system | basket holder | — | — | **→ ∅** |
| R13 | Loan's fundraising deadline passed | scheduler | lenders | — | — | **→ ∅ — no scheduler exists** |

**Reveal edges: 13 · implemented 4 · written silences 0 · unwritten silences 9.**

Every silence in this plane is silence by omission. Not one is a decision
somebody recorded. (Law 16 / A6.)

---

## Part B — Communication catalog

| Channel | Templates for lenders | State |
|---|---|---|
| In-app notification | 5 types (`loan_funded`, `disbursal`, `repayment`, `borrower_update`, `loan_outcome`) | `observed` |
| Email | **0** — `Swoosh` configured, `Mailer.deliver` never called anywhere in `lib/` | `observed` |
| SMS / push | 0 — no adapter | `observed` |
| Digest | 0 — no scheduler | `observed` |
| In-product assistant | Ask Mode over own portfolio; Command Mode previews `complete_demo_lend` | `observed` |

**Consequence:** the lender plane has exactly **one** channel, and it is pull-only.
Nothing the product learns can reach a lender who is not already looking at it.

---

## Part C — Artifact stories

| Artifact | Created | Owned | Seen by | Mutated | Retained | Deleted |
|---|---|---|---|---|---|---|
| `Lend` | at `complete_demo_lend` | lender | lender (portfolio), loan (aggregate count) | never | forever | **no path** |
| `BasketItem` | add to basket | lender | lender only | amount | **forever — no expiry, no sweep** | on checkout/clear only |
| `LendingTeam` | `create_lending_team` | founder | public | totals, member count | forever | **no path** |
| `TeamMembership` | **founder only, at creation** | team | team page | never | forever | **no path** |
| `TeamPost` + LC | `post_team_message` | author | team readers, translated on demand | moderation status | forever | **no path** |
| `EncouragementMessage` + LC | `submit_encouragement_message` | sender | borrower **if approved**; staff if held | moderation status, translations | forever | **no path** |
| `Notification` | on 5 reveal types | recipient | recipient | `read_at` | forever, **capped at 30 in the only view** | **no path** |
| `AIConversation` + messages + tool calls | on chat open | user | user; **admin can read the full transcript** | append | forever | **no path** |

**Artifact stories: 8 · with a deletion path: 0.**

Two carry an overexposure question rather than a gap:
`AIConversation` — every lender chat is readable verbatim in the admin inspector,
which is correct for support reconstruction and **never disclosed to the lender**.
`EncouragementMessage` — a held message's text is visible to staff, which is the
point, but the sender is never told it was read by anyone.

---

## Part D — Detail stories (the ones that carry risk)

| Detail | Source | Authority | Confidence | Visible to | Change | Delete |
|---|---|---|---|---|---|---|
| `Lend.amount_cents` | lender | human, committed | verified ($25-unit CHECK) | lender, aggregate | never | never |
| `loan.funded_amount_cents` | derived | service | **contradicted for 7,219 loans** (≠ sum of lendings) | public | on lend/simulate | — |
| `available_to_relend_cents` | derived | service | **derived from a capped estimate**, not a ledger | lender | recomputed | — |
| `repayment.lender_principal_returned` | derived | service | capped at principal (0% enforced) | lender | recomputed | — |
| `user.profile_public` | lender | human | **does not exist yet** | — | — | — |
| `Notification.read_at` | lender | human | reliable | lender | mark-all-read | never |
| AI conversation content | lender | human | verbatim | lender + **all staff** | append-only | never |

**Detail stories: 7 · unresolved confidence: 2** (`funded_amount_cents`
contradicted; `available_to_relend` presented as money but derived from an
estimate with no ledger behind it).

---

## Artifact & detail additions — folded back from critic round 1

| Artifact | Created | Retained | Deleted | Note |
|---|---|---|---|---|
| `ApiKey` | developer self-serve | forever | **no revoke path** | a leaked key cannot be withdrawn `observed` |
| `OAuthApp` + secret | developer self-serve | forever | no delete | `observed` |
| `User` (the lender themself) | seeds only | forever | **no deletion** | plane 14 absent |
| Session | login | until logout | — | `:user_return_to` written, never read `observed` |

| Detail | Authority | Confidence | Note |
|---|---|---|---|
| `loan.fundraising_ends_at` | service | **stale by design** — display-only; 3,989 loans past it | the lender reads "N days left" from a truth nothing enforces `observed` |
| `user.default_locale_code` | lender | reliable, **but shadowed** by session write-back | the lender's chosen language can be silently overridden `observed` |
| `loan.risk_summary_public` | *nominally the partner* | **template** when the partner leaves it blank | the risk sentence a lender reads may be system-authored `observed` |

**Revised: artifacts 12 (deletion paths: 0) · details 10 (unresolved confidence: 5).**

---

## Scope ruling on cross-plane artifacts

The critic reached three times for `Loan`, `RepaymentScheduleItem`, and
`BorrowerUpdate` lifecycles. **Ruling:** these are counterparty-plane artifacts;
their full create/own/mutate/retain/delete stories belong to the loan-lifecycle
compendium, not this one. This run enumerates them **only as the lender touches
them** — which is a real obligation, so the rows below exist. Recorded so the
boundary is a decision, not an oversight.

| Artifact (cross-plane) | The lender's relationship | State |
|---|---|---|
| `Loan` | the thing they backed; they see status, funded%, deadline, story | lender is **never told** when its status changes to trouble (R6) or when staff alter it (R11) `observed` |
| `RepaymentScheduleItem` | every lender return derives from these | **the lender never sees an installment** — only an aggregate; "who repaid what, when" is not reconstructable from their surfaces `observed` |
| `BorrowerUpdate` + LC | the emotional payload of lending | notified ✓, but **no aggregated feed**; with 1,408 loans, reading them means 1,408 visits `observed` |

| Detail (cross-plane, lender-facing) | Confidence | Note |
|---|---|---|
| `loan.status` | authoritative | but delinquent/defaulted are **never reachable live** and never revealed |
| `loan.disbursed_at` | authoritative | drives the lender's "reached the borrower" reveal ✓ |
| `repayment_schedule_item.due_on` / `.amount_cents` | authoritative | invisible to the lender; their chart aggregates it away |

**Revised: artifacts 15 (deletion paths: 0) · details 13 (unresolved confidence: 5).**
