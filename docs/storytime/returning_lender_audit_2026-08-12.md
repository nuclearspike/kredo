# StoryTime Audit — The Returning Lender

**Date:** 2026-08-12 · **Actor:** someone who has already lent, has money out in
the world, and has come back. Not a prospect — a participant.
**Scope:** the return journey. `/portfolio`, `/notifications`, the bell, the
relend loop into `/loans`, `/basket`, borrower updates, teams, and the reveal
layer that is supposed to pull them back at all.
**Method:** code read of the reveal and portfolio paths, plus a signed-in walk
as the demo lender (1,408 lendings, 655 completed, 164 in trouble) with the
notification and portfolio data queried directly.
**Deliverable:** audit only. Nothing here was implemented.

**Verdict in one line:** this actor is served a dashboard when what they came
for is news — and the news layer only ever tells them good things, anonymously,
after they independently decide to visit a site that never asked them to.

---

## 1. Why this actor is different

The visitor's question is *"should I care?"* This actor already decided. Their
questions are entirely about the interval since they left:

> *"Did anything happen? Did those people make it? How much came back? Who
> should I help next?"*

Every one of those is a **news** question. The product answers with a
**dashboard**: excellent at totals, silent on events. The gap between those two
things is this entire audit.

---

## 2. First-person layer (v1.12 seeds)

### Stage — Return (arriving after an absence)
> *"It's been a few weeks. Did anything happen? Did Salma finish? …There's a
> bell. Seven repayments. From who?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | What happened while I was gone? | notifications since last visit | A flat list of 30, undifferentiated, no since-marker (M4, M7) |
| 2 | Who repaid, and how much? | borrower name + amount per event | **Neither is in the notification** (H3) |
| 3 | Did anyone I backed get into trouble? | delinquency/default reveal | **Never told. 164 of their loans are in trouble; 0 notifications** (H2) |
| 4 | Did any of my loans finish? | completion reveal | **655 completed, no distinct moment** (H4) |
| 5 | How much can I lend again? | available_to_relend | ✓ Answered well, and it is the hero's one action |
| 6 | Who should I help next? | a relend suggestion | Dropped at an unpersonalized list of 3,992 (M2) |

### Stage — Redeploy (money came back, putting it out again)
> *"$92,840 ready. Okay — same as last time? More Jordan? Someone nearly
> funded? …I'm just looking at everything again."*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | How much do I have? | available_to_relend | ✓ Stated in the banner, in money |
| 2 | Who did I back before, and can I do it again? | their borrower history | **No repeat-lending path, no "my borrowers"** (M3) |
| 3 | What's nearly finished that I could close? | almost-funded loans | Not surfaced; the assistant knows this intent, the UI doesn't |

---

## 3. Findings

### 🔴 HIGH

**H1 — Nothing brings this actor back. The product has reveals but no delivery.**
Swoosh is configured — dependency, `Kiva.Mailer`, a dev mailbox route — and
**`Mailer.deliver` is never called anywhere in `lib/`**. Every notification is an
in-app row waiting to be discovered. A lender learns their loan was repaid only
by independently deciding to visit. For an actor whose entire relationship is
episodic — money goes out, months pass, money comes back — a reveal layer with
no outbound channel means the return journey has no trigger.
*Impact:* the whole story below only runs if the actor spontaneously remembers
to come back. Everything else is downstream of this.

**H2 — The reveal layer carries only good news.**
A lender is notified on `loan_funded`, `disbursal`, `repayment`,
`borrower_update`, and `loan_outcome`. There is no reveal for delinquency,
default, or a loan falling behind — and no live code path even sets those
statuses: grep for `status: "delinquent"` / `status: "defaulted"` in `lib/`
returns nothing but a compat *reader*. Those states arrive only from the seed
and generator.
Measured on the demo lender: **164 of their loans are delinquent or defaulted,
and they have received zero notifications about any of them.** All 97 reveals
they have ever received are good news.
*Impact:* the product tells this actor when money arrives and never when it
does not. The portfolio then shows "Behind schedule: $22,396" as though they
were always aware. That is not a UI gap; it is the product being untruthful by
omission to the person carrying the risk.

**H3 — Notifications are anonymous, so the reveal strips what makes it matter.**
Every repayment reveal reads *"Repayment received — A loan you supported
received a repayment — your balance to relend grew"*
([lending.ex:870](../../lib/kiva/lending.ex#L870)). **No borrower name, no
amount, no loan title.** Signed in as the demo lender, the page is five
identical cards in a row. The one thing the actor wants — *Salma finished her
third payment, $118* — requires clicking "View →" on each, one at a time.
`notify_loan_lenders/5` has the loan in hand and passes a static string.
*Impact:* this is the emotional core of lending, rendered as system log output.
The most fixable high-severity finding in the audit.

**H4 — A loan completing is not a moment.**
The final repayment flips the loan to `completed`
([lending.ex:858](../../lib/kiva/lending.ex#L858)) and then emits the *same
generic* "Repayment received" as installment 3 of 14. The demo lender has **655
completed loans** and has never once been told a story finished.
*Impact:* the payoff the entire journey builds toward — a stranger borrowed,
worked, and paid you back in full — is indistinguishable from routine. This is
the single biggest missed opportunity for delight in the product.

### 🟡 MEDIUM

**M1 — No "what happened to my borrowers" feed.** Borrower updates are notified,
but they are only *displayed* on the individual loan page
([show.ex](../../lib/kiva_web/live/loan_live/show.ex), "Updates from the field").
With 1,408 lendings, seeing what your borrowers wrote means 1,408 page visits.
The single most engaging content the product produces has no aggregated surface.

**M2 — The relend loop dead-ends in a generic list.** "$92,840.16 ready to
relend → Find a borrower" lands on `/loans`, which knows the actor only well
enough to decide `can_lend`
([index.ex:276](../../lib/kiva_web/live/loan_live/index.ex#L276)). It does not
know they favour Jordan and clothing, that they have backed 1,268 borrowers, or
that they arrived holding a specific amount. A convergence failure in doc-9
terms: one lived moment ("I have money back, who needs it?") toured across two
unconnected surfaces.

**M3 — No repeat lending, and no "my borrowers".** A lender cannot follow a
borrower, cannot lend to the same person again, and has no view of the people
(as opposed to the loans) they have backed. The portfolio groups by country,
status, sector, and partner — every dimension except the human one.

**M4 — Nothing marks the interval.** `read_at` exists and `unread_count/1` feeds
the bell, but no surface frames a return: no "since your last visit", no
grouping by period, no digest. The actor's defining question — *what changed?* —
has no answering truth.

**M5 — The risk breakdown is still a decision, not a surface.** The dedicated
losses/arrears/FX page was ruled in on 2026-08-11
(`decision.lender_risk_details_page`) and does not exist yet. Combined with H2,
this actor currently has neither a push telling them about trouble nor a page
explaining it.

**M6 — The social loop is invisible from the return path.** Lending teams have
message boards and translation, and a lender can lend on a team's behalf — none
of it is surfaced on `/portfolio`, the page this actor actually lands on.

**M7 — Notifications do not survive volume.** `list_for_user/2` caps at 30 with
no grouping, filtering, or pagination. At demo scale that is a truncated,
unsorted-by-meaning pile.

### 🟢 LOW

**L1 — Reveal links are inconsistent.** `loan_funded` and `disbursal` link to the
loan; `repayment` links to `/portfolio`. The one reveal that names a specific
event sends the actor to a summary instead of the story.

**L2 — No notification preferences.** Moot until H1 exists, but any outbound
channel needs frequency and opt-out from day one.

**L3 — The basket is absent from the return journey.** It exists and is in the
header, but nothing in the relend flow proposes building one, which is the
natural shape of redeploying $92,840 across several borrowers.

### ❓ QUESTIONS

1. **Should loans be able to go bad in the running product?** Today only seeded
   data is ever delinquent or defaulted. Adding a live path (via the time
   machine, most naturally) is what makes H2 fixable and makes the risk story
   real rather than decorative.
2. **What is the intended return cadence?** Per-event email, a weekly digest, or
   in-app only by design? This decides whether H1 is a gap or a scope boundary —
   and the honest answer may be "digest", since 72 repayment emails is its own
   failure.
3. **Is repeat lending to the same borrower in the domain?** Real Kiva mostly
   lends to a borrower once per loan; "follow this borrower" may be the truer
   shape than "lend again to Salma".

---

## 4. Story debt summary

1. A reveal layer with no delivery: nothing ever reaches this actor (H1).
2. Reveals that are structurally incapable of bad news, while 164 of their loans
   are in trouble (H2).
3. Reveals that omit who, how much, and which loan (H3).
4. The story's ending — full repayment — emitted as routine (H4).
5. The most engaging content (borrower updates) reachable only one loan at a
   time (M1).
6. The relend moment split across two surfaces, neither of which knows the actor
   (M2, M3).

---

## 5. What would make this compelling

Ordered by value per unit of work.

**1. Put the borrower back into the reveal.** `notify_loan_lenders/5` already
holds the loan. *"Salma Haddad made her 3rd repayment — $118.75 came back to
you"* costs a string interpolation and transforms the surface from a system log
into news about people. Highest value, lowest cost in this audit.

**2. Make completion its own moment.** When the last installment lands, emit a
distinct reveal: *"Salma has fully repaid. You lent $25 and got $25 back — and
she finished her school-uniform order."* A closing beat, ideally with the
borrower's photo and the option to relend it immediately in one step. The
product currently has 655 of these moments per lender, all unspent.

**3. Tell them when something goes wrong.** Requires answering Q1. A lender who
only hears good news cannot trust the good news. Pair the reveal with the
already-decided risk details page (M5) so the notification has somewhere honest
to land.

**4. Open on "since you were gone."** The portfolio hero answers *what has my
money done*, which is the right lifetime question and the wrong return question.
Above it, or as the notifications page's headline: *"Since 14 July: 7 repayments
($412 back), 2 loans fully repaid, 1 loan behind schedule."* All four truths
already exist; only the framing is missing.

**5. Build the borrower feed.** One page: updates and outcomes from the people
this lender backed, newest first, with photos. It is the answer to the actor's
first question and the content already exists — it is simply only reachable one
loan at a time.

**6. Make the relend moment know who is standing in it.** Carry the amount into
`/loans` ("$92,840 to lend — here are borrowers in the places you've backed
before"), and offer the shortest safe path: almost-funded loans they could
finish, or a basket pre-shaped to the amount. One moment, one surface.

**7. Give them their people, not just their loans.** A "borrowers you've backed"
view — faces, countries, what happened to each. The portfolio slices by every
dimension except the one that made them lend in the first place.

---

## 6. What is already working (do not regress)

- **The impact hero.** Total lent, repaid ring, borrowers and countries reached
  — it answers the lifetime question immediately and in the right order.
- **"$92,840.16 ready to relend"** as the page's single action, in money rather
  than jargon, with one button.
- **The repayment chart** — cumulative scheduled vs received, with the gap
  legible as "behind schedule", and a table fallback.
- **Slice-and-dice with URL-backed state** — genuinely good for a portfolio this
  size, and shareable.
- **0% honesty throughout.** No yield language survives anywhere on this path.
