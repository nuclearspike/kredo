# StoryTime Audit — Staff Working the Loan and Translation Queues

**Date:** 2026-08-12 · **Actor:** a staff reviewer who has sat down to clear
queues. They decide whether a borrower's listing goes live and whether a
translation is faithful enough to publish in someone's name.
**Scope:** the reviewing journey — `/admin`'s loan review queue and translation
review queue, the approve/reject commands behind them, the evidence each
decision is made on, and what those decisions reveal to the people waiting.
**Method:** code read of the review paths plus queries for the real shape of the
queues at demo scale.
**Deliverable:** audit only. Nothing here was implemented.

**Verdict in one line:** the loan review card is the best-evidenced decision
surface in the product, and the translation queue beside it is the worst — the
reviewer is asked to certify that a translation is faithful without being shown
the original, from a queue displaying **0.015%** of the work, where pressing
Reject silently makes the loan unpublishable forever.

---

## 1. The two queues are not peers

| | Loan review | Translation review |
|---|---|---|
| Items now | **0** | **679,460** awaiting, **100 shown** |
| Evidence given | story, use, risk, repayment, per-locale coverage, missing-field list | a truncated snippet of the target text |
| Decisions | approve · request changes (with reason) | approve · reject (no reason) |
| Repair path | ✓ back to partner, resumable | **none** |
| Reveals on decision | ✓ partner notified both ways | **nobody** |

The page leads with the empty one.

---

## 2. First-person layer (v1.12 seeds)

### Stage — Working the translation queue
> *"German, 'Sokha Kim Großhandelswaren'. Is that right? I don't have the
> English. …It looks plausible. Approve, I guess."*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | What did the original say? | the source row | **Not shown. The single most necessary truth is absent** (H2) |
| 2 | Who or what produced this? | method + model | Not shown (machine vs template vs human) |
| 3 | How much is waiting? | queue depth | **Not shown; the list silently caps at 100** (H3) |
| 4 | What happens if I reject it? | the consequence | **Nothing tells them it ends the loan's life** (H1) |
| 5 | Can I just fix the wording? | an edit path | **No such command exists** (M1) |
| 6 | Is someone else working this? | claim/lock | No (M4) |

**Transcription target for the header:** *"679,460 translations waiting —
oldest 3 weeks. Showing the 100 most recent."*

### Stage — Working the loan review queue
> *"Salma Haddad, school uniforms, Jordan, $2,000. Story's there, risk line's
> there, Spanish and Dutch still machine. Do I hold it or send it back?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | Is this listing complete? | `review_detail.missing` | ✓ **Explicitly listed** |
| 2 | What will lenders read? | story, use, risk, repayment | ✓ All present in the card |
| 3 | Which languages are ready? | per-locale badges | ✓ Shown with status |
| 4 | If not, what do I do? | request changes + reason | ✓ Real repair path, partner notified |

---

## 3. Findings

### 🔴 HIGH

**H1 — Rejecting a translation is a permanent dead end, and since 2026-08-11 it
permanently blocks the loan.**
`Translation.reject/3` sets `translation_status: "rejected"`
([translation.ex:178](../../lib/kiva/translation.ex#L178)). From there:

- `build_queue/3` selects only `machine` and `needs_review`, so the row **leaves
  the review queue and never returns**;
- `Resolver.@display_statuses` excludes `rejected`, so that locale silently falls
  back to English;
- **no command anywhere sets it back** — there is no re-translate, regenerate, or
  edit path (grep across `lib/` finds only the reject write itself);
- and `all_locales_translated`, the publish gate added on 2026-08-11, requires
  every locale to be `approved` or `published` — so the listing **can never be
  published**.

A reviewer doing their job correctly — refusing a bad machine translation —
bricks the borrower's loan, with no warning, no undo, and no surface anywhere
that shows the loan is now stuck.
*Footprint:* **0 rejected rows today**, so nothing is stuck yet. The trap is
armed, not sprung.
*Ownership:* the dead-end half predates me; **the permanent-block half is mine.**
I added the gate on instruction and did not check what `rejected` did to it. The
gate is still right; it needs `rejected` to have somewhere to go.

**H2 — The reviewer certifies faithfulness without being shown the original.**
A translation queue row carries `snippet: snippet(Map.get(r, field))` — a
**truncated slice of the target text only**
([translation.ex](../../lib/kiva/translation.ex)). No source text, no
side-by-side, no method (machine / template / human), no confidence, no link to
the loan. Approving a translation is precisely the act of asserting it matches
the original, and the surface withholds the original.
*Impact:* every approval on this queue is a guess. This is the reviewer's core
act and it is unsupported. (Raised in the dashboard audit as H4; it belongs here
as this actor's central finding.)

**H3 — The queue shows 0.015% of the work and says nothing about the rest.**
`build_queue/3` hard-limits **100 rows per entity type**. Measured: **679,460**
loan translations are in `machine` or `needs_review`. There is no total, no
"showing 100 of 679,460", no pagination, no filter by locale or age, and no
indication a cap exists.
*Impact:* Law 19 — compression must preserve count and worst-state. A reviewer
clearing this queue believes they are finishing and is looking at a rounding
error. Directly contradicts the "Translation coverage by locale" analytics card
on the same page, which shows over a million.

### 🟡 MEDIUM

**M1 — Binary decision, no repair.** There is no command to edit or correct a
translation. A reviewer looking at nearly-right German must either approve text
they believe is flawed or reject it into H1's limbo. The middle response — the
common one in real review work — does not exist.

**M2 — Rejection carries no reason.** `reject/3` accepts only a reviewer id.
Nothing records why, so nothing can be learned, relayed to the partner, or used
to improve the machine translator. Compare `request_loan_changes`, which takes a
reason and delivers it — the loan queue got this right and the translation queue
did not.

**M3 — Translation decisions reveal to nobody.** `record_review_provenance/4`
writes the event with `visibility: "admin"`. The partner is waiting on exactly
this queue (partner audit, M3) and is told nothing; the borrower is told nothing
(borrower audit, H1). The gate I added made this queue load-bearing for
publication without giving anyone downstream a window onto it.

**M4 — No claiming, no locking, no presence.** Two reviewers working the same
queue will act on the same rows. The second one's approve simply lands on an
already-decided row — now refused by `translation_awaiting_review` since
2026-08-11, which is better than a silent double-write, but the surface still
gives no hint anyone else is there.

**M5 — Priority inversion.** The page opens with distribution analytics, then
"Loan review queue **0**", then the translation queue that is 679,460 deep. The
reviewer's actual work is third on a page led by a number that is zero.

**M6 — No bulk path at this volume.** Approving machine translations above a
confidence threshold is open as `question.localization.bulk_translation_approval`
and unruled. At 679,460 items, individual clicking is not a strategy — it is a
guarantee the queue is never worked.

**M7 — No aging anywhere.** Neither queue shows how long anything has waited.
The reviewer cannot triage by staleness, and the partner's wait is invisible from
this side as well as their own.

### 🟢 LOW

**L1 — Queue rows are identified by entity type, locale, and a snippet** — not by
the loan or borrower they belong to. A reviewer cannot tell which listing they
are affecting.
**L2 — No reviewer workload or throughput view** — nothing shows what this
reviewer has cleared, or what the team's rate is against the backlog.
**L3 — The "Translation coverage by locale" card reports an identical number for
all five locales**, which is vacuous as a signal (dashboard audit, M5).

### ❓ QUESTIONS

1. **What should rejection mean?** Regenerate a fresh machine translation? Send
   it back to the partner as changes-requested? Mark the locale permanently
   unavailable and let the loan publish with a documented gap? **H1 cannot be
   fixed until this is answered**, and it is now urgent because the publish gate
   depends on it.
2. **Should bulk approval exist, and on what evidence?** Already open. The
   honest options are a confidence threshold, a per-partner trust level, or
   accepting that machine translations publish unreviewed with a badge.
3. **Should translation decisions reveal to the partner?** They are waiting on
   this queue and cannot see it.

---

## 4. Story debt summary

1. A correct reviewer action that silently and permanently bricks a loan (H1).
2. The central act of the role — certifying faithfulness — performed without the
   source text (H2).
3. A queue that hides 99.985% of itself with no count (H3).
4. No middle response between approve and destroy (M1), and no reason recorded
   when destroying (M2).
5. A queue that now gates publication and reveals nothing to anyone waiting on
   it (M3).

---

## 5. What would make this compelling

**1. Give `rejected` somewhere to go.** Answer Q1 first. Whatever the ruling, the
row must either re-enter a queue, return to the partner, or explicitly release
the publish gate. Until then, the safest immediate step is for the loan review
card to show "this loan cannot publish: German was rejected" so the block is at
least visible.

**2. Show the source.** Side-by-side original and translation, with the method
and the loan it belongs to. This converts the queue's core act from a guess into
a judgement, and costs one join.

**3. Tell the truth about the queue.** *"679,460 waiting · oldest 3 weeks ·
showing 100 most recent"*, with locale and age filters. A reviewer who knows the
real shape can make a strategy; one who thinks there are 105 items cannot.

**4. Add the middle response.** Let the reviewer fix the wording and approve in
one step. Most review work is correction, not verdict — and it would make the
human-translated status meaningful, which the schema already supports.

**5. Carry a reason on rejection, and deliver it.** `request_loan_changes`
already proves the pattern on the loan queue: a reason, delivered to the partner,
with a resumable repair. The translation queue should borrow it wholesale.

**6. Lead the page with the work.** Queue counts and oldest-age at the top,
analytics collapsed at the bottom. Same conclusion the dashboard audit reached.

**7. Decide bulk approval.** At this volume the alternative to a ruling is not
careful review; it is a queue nobody ever touches and a translation layer that is
reviewed in name only.

---

## 6. What is already working (do not regress)

- **`review_detail/2` is the best decision surface in the product.** Story, use,
  risk, repayment summary, per-locale translation coverage, and an explicit list
  of missing fields — its own comment says it exists "so staff approve with eyes
  open, not blind", and it delivers on that.
- **`request_loan_changes` is a complete repair loop**: a reason, a reveal to the
  partner, a resumable state, and an audit event. It is the model the rest of the
  review surface should copy.
- **Reviewer attribution is real.** Approve and reject both record the reviewer's
  name and role into the hash-chained provenance trail, so a listing's review
  history is reconstructable long afterwards.
- **Every decision routes through the command registry** and is audited; since
  2026-08-11 a second reviewer acting on an already-decided row is refused rather
  than silently double-writing.
