# StoryTime Audit — The Partner Submitting a Loan Application

**Date:** 2026-08-12 · **Actor:** a field partner (MFI) staff member entering a
borrower's loan into the platform and sending it for review. They have met the
borrower. They are vouching for them.
**Scope:** the submission journey — enrol or pick a borrower, open a draft, fill
it, submit, wait, and respond to requested changes. `/partner`, the draft form,
`Kiva.LoanApplications`, the partner's slice of the command registry, and the
reveals that cross to and from staff.
**Method:** code read of the application and review paths plus queries against
the demo database for the shape of the draft backlog.
**Deliverable:** audit only. Nothing here was implemented.

**Verdict in one line:** this is the **best-served actor in the product** — ten
commands, reveals in both directions, a real workspace — which is exactly why
its remaining gaps matter: the partner is never asked for the one sentence
lenders rely on, is refused in language they cannot read, and can never throw
anything away.

---

## 1. Where this actor stands relative to the others

Worth stating plainly, because it reframes every finding below:

| Actor | Commands | Reveals received |
|---|---|---|
| Borrower | 2 (neither about their loan) | **none** |
| Lender | 6 | good news only, anonymous |
| **Partner** | **10** | **`loan_approved`, `changes_requested`** |

The partner has a working two-way relationship with staff. Nothing here is a
missing plane; it is a built plane with sharp edges.

---

## 2. First-person layer (v1.12 seeds)

### Stage — Filling the application
> *"María needs 8,000 quetzales for the loom. I've got her details from last
> year… does it remember? What else do they need from me before this goes?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | What do they need from me? | required-field set | Seven fields are checked; **none are named to the partner** (H2) |
| 2 | Can I reuse what I know? | reuse suggestion | Amount + term only, no source, no confidence (M4) |
| 3 | Is this ready to send? | `draft_complete?` | Discoverable only by pressing submit and being refused |
| 4 | How will lenders see this? | listing preview | **No preview exists** (L3) |

### Stage — After submitting
> *"Sent. …Now what? How long does review take? Is anyone looking at it?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | Did it go? | status change | ✓ Flash: "Submitted for staff review. Translation jobs queued." |
| 2 | Where is it in the queue? | queue position / age | **No such truth** (M2) |
| 3 | What is it waiting on? | the translation gate | **Invisible** — added 2026-08-11, never surfaced (M3) |
| 4 | What if they want changes? | `changes_requested` reveal | ✓ Notified with the reason, links back to `/partner` |

---

## 3. Findings

### 🔴 HIGH

**H1 — The risk disclosure lenders read is written by the system and attributed
to the partner.**
`draft_complete?/1` requires borrower, sector, amount, term, title, story, and
loan use — **not** `risk_summary_public`
([loan_applications.ex](../../lib/kiva/loan_applications.ex)). On submit,
`ensure_risk_summary/1` silently writes:

> *"Reviewed by the field partner; standard repayment terms apply."*

The partner is never asked for it. The sentence a lender reads as the honest
statement of risk — phrased as though the partner reviewed and said so — is a
template the partner never saw.

Worse, this defeats its own gate: `approve_loan_listing` declares
`risk_summary_present`, which **can never fail**, because the fallback has
already satisfied it before staff ever open the loan. A second gate that looks
enforced and is not (compare `all_locales_translated`, fixed 2026-08-11).
*Footprint:* zero rows today — all 1.1M seeded loans carry generator-written
summaries — but the path fires for **every real partner submission**.
*Impact:* the product's central honesty claim ("never claim repayment is
guaranteed", risk stated plainly) rests on a sentence nobody wrote.

**H2 — The refusal speaks implementer, not partner.**
A blocked submit shows: *"Not ready to submit: **draft_complete**. Complete all
required fields."*
([partner_live.ex:142-149](../../lib/kiva_web/live/partner_live.ex#L142)) — the
raw eligibility check name, interpolated into an actor-facing string, naming
none of the seven fields it actually tested. The partner must guess which of
borrower, sector, amount, term, title, story, or use is missing.
*Impact:* Law 15 and A44 in one line. The server knows exactly what is missing
and tells the actor a symbol instead.

**H3 — Drafts are permanent. There is no bail path.**
No discard, delete, archive, or cancel exists anywhere for a loan draft —
searched `LoanApplications`, the command registry, and the workspace. A partner
who opens an application for the wrong borrower, or abandons one, has created a
row that can never be removed. **2,064 drafts** are already sitting in the demo
database with no lifecycle at all.
*Impact:* Law 9 — abandonment is a story path and this one has no state, no
retention rule, and no cleanup. Combined with the raw-ID drafts wall from the
dashboard audit, the workspace can only accumulate, forever.

### 🟡 MEDIUM

**M1 — "Chat-assisted" is a claim, not a capability.** The workspace's own
moduledoc calls it a *"chat-assisted loan application workspace"*, and the
assistant's partner contract promises *"chat-first guided collection"* and
reusing prior details *"only after showing your confidence and asking for
confirmation"* ([llm.ex](../../lib/kiva/ai/llm.ex)). The implementation is
`live_chat={true}` — the generic assistant, which has no partner commands wired
into it at all (`Kiva.AI.Assistant` handles `set_locale` and lending). The
distinctive premise of this actor's journey is described in three places and
built in none.

**M2 — After submitting, the partner is blind until the verdict.** No queue
position, no age, no expected turnaround, no indication anyone has looked. The
next thing they hear is the decision.

**M3 — The new translation gate is invisible to the person waiting on it.**
Since 2026-08-11 a listing cannot publish until all five languages are reviewed
(`policy.listing.every_language_before_live`). The partner submits, machine
translations are generated, and their loan now waits on a staff queue they
cannot see and were never told exists. A delay was added to their journey with
no corresponding truth on their surface.

**M4 — The reuse suggestion under-delivers on its own promise.** It offers prior
amount and term as a single "Use prior terms" button — no source attribution
("from María's 2024 loom loan"), no confidence, no per-field application, and
nothing for the fields that are actually laborious (story, use, photo). The
contract says show confidence and ask; the UI shows a number and a button.

**M5 — No draft aging, ordering, or triage.** 2,064 drafts listed by id, with no
started-at, no age, no sort, no filter. The one differentiator that matters —
`changes_requested`, meaning staff are waiting on *them* — is mixed into the
same undifferentiated list.

**M6 — Partner reveals fan out to the whole organization.**
`notify_partner/5` notifies every user whose `managed_partner_id` matches
([notifications.ex](../../lib/kiva/notifications.ex)), with no notion of who
submitted the loan. Fine for a single-user demo org; wrong the moment a partner
has two staff.

**M7 — No borrower search.** Thousands of borrowers behind blind Prev/Next, with
generated names that repeat. Carried from the dashboard audit; it bites hardest
here, because finding the right borrower is step one of every submission.

### 🟢 LOW

**L1 — Draft rows are labelled by raw id** (`#3000003 · draft`) rather than by
borrower, title, or date. Recorded already as an H3 in the dashboard audit.
**L2 — The new-borrower form offers three hardcoded countries** (Guatemala,
Kenya, United States) while the platform's data spans fourteen
([partner_live.ex](../../lib/kiva_web/live/partner_live.ex)).
**L3 — No listing preview.** The partner cannot see the borrower's story as
lenders will read it before committing to submit it.

### ❓ QUESTIONS

1. **Should the partner write the risk summary?** If yes, it belongs in
   `draft_complete?` and the fallback should be deleted. If no, the sentence must
   stop implying the partner reviewed and concluded anything, and
   `risk_summary_present` should be retired rather than left as a gate that
   cannot fail. This is the decision that resolves H1.
2. **What is the retention rule for abandoned drafts?** Deletable by the partner,
   auto-expired after N days, or permanent by design? H3 cannot be fixed before
   this is answered.
3. **Is chat-first collection still intended?** If yes it is a substantial build.
   If no, the moduledoc and the assistant's partner contract should be corrected
   so the documentation stops describing a product that does not exist.

---

## 4. Story debt summary

1. The honest-risk sentence is authored by the system, and the gate meant to
   enforce it is satisfied by that same fallback (H1).
2. The refusal names an internal check instead of the missing fields (H2).
3. No bail path: 2,064 permanent drafts and no way to discard one (H3).
4. A documented chat-first premise with no implementation (M1).
5. A newly added wait (translation review) with no window onto it (M3).
6. Everything the partner needs to triage — age, borrower name, who is waiting on
   whom — absent from the list they work from (M5, M7, L1).

---

## 5. What would make this compelling

**1. Name the missing fields.** The server already evaluated all seven. Return
them and say *"Still needed: the loan's purpose and María's story."* This is the
single cheapest improvement in the audit and removes a guessing game from the
most-used path.

**2. Decide the risk summary, then honour it.** Answering Q1 either adds one
required field to the draft — the field that carries the product's honesty
promise — or removes a sentence that misattributes authorship. Either is better
than a template signed by someone who never read it.

**3. Let them throw things away.** A discard on a draft, with the retention rule
from Q2 behind it. Nothing about this actor's workspace works until it can
shrink as well as grow.

**4. Show them the queue.** *"Submitted 3 days ago · waiting on translation
review in German and French · typically 2 days."* All three truths exist today;
none of them reach the person waiting. This also makes M3's new gate legible
instead of mysterious.

**5. Make reuse worth trusting.** *"María's 2024 loom loan: $500 over 8 months —
use these?"* with per-field application. Attribution and confidence are what turn
a prefilled number into a decision the partner can stand behind.

**6. Rebuild the list around today's work.** Bounced applications first, labelled
by borrower and age; then drafts in progress; then start-a-new-application. The
dashboard audit reached the same conclusion from the other direction — this is
the same fix.

**7. Preview as a lender.** One button showing the listing as it will appear.
The partner is vouching publicly for someone they know; letting them read it
first is both dignity and quality control.

---

## 6. What is already working (do not regress)

- **A genuine two-way relationship with staff.** `loan_approved` and
  `changes_requested` both reveal to the partner, and the latter carries the
  reviewer's reason and a link back. This is the only complete reveal loop in the
  product.
- **`changes_requested` is a real state**, surfaced with its reason on the
  workspace and resumable via "Address changes" — a proper repair path.
- **Machine translations are generated on submit**, so the partner writes in one
  language and the platform handles the other four.
- **Borrower reuse exists at all** — the idea is right even where the execution
  is thin.
- **Every mutation goes through the command registry** with ownership checks
  (`partner_owns_draft`), so a partner cannot touch another organization's work.
