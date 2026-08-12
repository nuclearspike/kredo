# StoryTime Audit — The Borrower Waiting for Their Loan to Fund

**Date:** 2026-08-12 · **Actor:** a borrower whose application was approved and
published. The money has not arrived. Strangers are deciding.
**Scope:** the waiting interval — from listing approval to fully funded, or to
whatever happens instead. `/portal`, the reveal layer as it reaches (or fails to
reach) a borrower, `fundraising_ends_at`, and the affordances available to the
`borrower` role.
**Method:** code read of the reveal, portal, and lifecycle paths, plus queries
against the demo database for what waiting actually looks like at scale.
**Deliverable:** audit only. Nothing here was implemented.

**Verdict in one line:** this is the only actor in the product with **zero
reveals** — nobody ever tells a borrower anything — and the wait they are in has
no defined ending, because 3,989 of 3,992 fundraising loans are already past
their own deadline and no code anywhere acts on that date.

---

## 1. The stage

One person's livelihood, suspended, while a crowd they cannot see decides. Their
questions are simple and almost none are answered:

> *"Is it working? Is anybody actually helping? How long does this take? What
> happens if nobody does? Is there anything I can do?"*

The lender's equivalent moment is richly served — a hero, a chart, a ring, a
relend banner. The borrower's is a progress bar and a repayment date for money
they have not received.

---

## 2. First-person layer (v1.12 seeds)

### Stage — Awaiting funding
> *"¿Ya llegó? Setenta y seis por ciento… ¿quién es esa gente? ¿Cuánto más
> falta? ¿Y si no se completa?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | Is it working? | funded % / amount remaining | Present as a bar. Never headlined, never narrated (M1) |
| 2 | Is anybody actually helping me? | lender count, origins | **Not shown to the borrower at all** (M2) |
| 3 | How long does this take? | typical time-to-fund | **No such truth exists anywhere** (M5) |
| 4 | What if it doesn't fund? | expiry policy | **Undefined.** No expiry path, no reveal, no rule (H2) |
| 5 | Can I do anything? | available decisions | Two commands exist for this role, neither about their loan (H4) |
| 6 | Did someone say something to me? | encouragement | Shown if approved — but they are never told it arrived (H1) |

**Transcription target (es-source), replacing "My portal":**
*"Tu préstamo está al 76% — faltan $225. Catorce personas ya te apoyaron."*

---

## 3. Findings

### 🔴 HIGH

**H1 — Nobody ever tells the borrower anything. The reveal layer has no borrower
plane at all.**
`Kiva.Notifications` exposes `notify_loan_lenders/5` and `notify_partner/5`.
There is **no `notify_borrower`** — grep across `lib/` returns nothing. The
command registry declares `notify_borrower_if_visible` as a side effect of
`submit_encouragement_message`
([commands.ex:79](../../lib/kiva/commands.ex#L79)) and **no function by that name
exists**: it is a phantom side effect, declared and never built.

Traced through the waiting interval:

| Event | Partner | Lenders | **Borrower** |
|---|---|---|---|
| Listing approved, goes live | ✓ notified | — | **silence** |
| Someone lends | — | — | **silence** |
| Fully funded | — | ✓ notified | **silence** |
| Disbursed | — | ✓ notified | **silence** |
| Encouragement approved | — | — | **silence** — `approve_message/1` translates the message *into their language* and never tells them it exists ([messaging.ex](../../lib/kiva/messaging.ex)) |

*Impact:* the actor with the most at stake is the only one the product never
speaks to. Every other plane has a reveal path. This is Law 4 and Law 5 failing
for one actor completely, not partially.

**H2 — The wait has no ending. Nothing anywhere acts on the deadline.**
Every use of `fundraising_ends_at` is rendering ("N days left"), sorting, or API
serialization — thirteen references, not one of them a transition. There is **no
background job infrastructure at all** (no Oban, no GenServer, no scheduled
task), so an expiry could not run even if it were written.
Measured: **3,989 of 3,992 fundraising loans are past their own stated deadline**,
the oldest since **2023-06-09**. Worse, `days_left/1`
([view_helpers.ex](../../lib/kiva_web/view_helpers.ex)) returns `nil` for a past
date, so the countdown badge silently disappears — an expired loan is visually
indistinguishable from a fresh one.
*Impact:* the single most likely outcome of this stage — *it doesn't fund in
time* — has no state, no reveal, no policy, and no story. Law 9 says bail paths
are story paths; this one does not exist. A borrower can wait three years.

**H3 — The portal tells a waiting borrower when to repay money they have not
received.**
`next_payment/1` finds the first `scheduled` item **or falls back to
`List.first(items)`** ([portal_live.ex:23-27](../../lib/kiva_web/live/portal_live.ex#L23)),
and the template renders it whenever it is non-nil, regardless of loan status
([portal_live.ex:67](../../lib/kiva_web/live/portal_live.ex#L67)). Verified on
screen: *"Rosa's second weaving loan · fundraising · $725 of $950 · 76%"*
immediately followed by *"Next repayment: 2026-12-28 — $118.75."*
*Impact:* for a lender this class of bug is a cosmetic lifecycle leak. For this
actor it is the product asserting a debt obligation against someone who has not
been given anything. It is the most harmful single line in the borrower surface.

**H4 — The borrower cannot speak.**
`Commands.for_actor("borrower")` returns exactly **`post_team_message` and
`set_locale`** — one command about lending teams they are not in, and a language
switch. `post_borrower_update`, the one command that would let them tell their
supporters how it is going, is **partner/staff only** and has no surface anywhere
(already open as `question.portal.borrower_update_authoring`).
*Impact:* they cannot thank anyone, correct their own story, answer a question,
report that circumstances changed, or ask what is happening. The plane is
read-only for the person it is about.

### 🟡 MEDIUM

**M1 — The portal answers nothing before it offers.** The page opens *"My
portal"* / *"Welcome, Rosa. Here are your loans in your language."* Their
top-of-stack question — *is it working?* — is answerable only by interpreting a
bar. The truths to headline it (funded %, amount remaining, days left) are all
already loaded.

**M2 — No social proof for the person who most needs it.** Lenders see lender
counts on every card; the borrower sees a bar. *"Fourteen people in six countries
have backed you"* is computable today from `lender_counts/1` and is never shown
to the one person for whom it is not a metric but reassurance.

**M3 — Encouragement is one-way and anonymous.** Messages arrive translated, with
no sender and no reply path. The public-profile-gated reveal was ruled in on
2026-08-11 (`decision.encouragement_sender_reveal`) and is not built; the thank
path does not exist as a command at all.

**M4 — The borrower plane barely exists in the data.** **1 of 100,203 borrowers
has a linked user account** (0.001%). The portal is a surface for exactly one
person. Whether that is a demo artifact or the intended model is unruled (Q1),
but it means this journey has never been walked at any realistic scale.

**M5 — No expectation is ever set.** Nothing tells a borrower how long funding
typically takes, what fraction of loans fund, what happens on the day the
deadline passes, or what happens after full funding. The waiting is not just
unresolved, it is uncontextualised.

**M6 — The language promise breaks for this actor specifically.** The locale
precedence bug (`finding.localization.locale_precedence_defeats_default`) means
an es-default borrower can be shown an English portal whose own text reads *"Here
are your loans in your language."* Of all the actors, this one was promised
native language most explicitly.

### 🟢 LOW

**L1 — The fallback badge prints a raw locale code** (`EN`) where actor phrasing
belongs.
**L2 — The borrower cannot see their own public listing** — the story, photo, and
risk summary that strangers are reading about them.
**L3 — Completed loans render as husks** (title + badge, no closure), carried
over from the dashboard audit.

### ❓ QUESTIONS

1. **What should happen when a loan does not fund in time?** Partial funds
   released? Relisted? Cancelled and the lenders refunded? This is unruled, and
   it blocks H2 entirely — the expiry reveal cannot be written before the policy
   exists. It is the most consequential open question in this audit.
2. **Are borrower accounts intended at all?** At 0.001% coverage the real model
   looks partner-mediated, where the partner relays news. If so, the honest fix
   is a partner-facing "tell your borrower" affordance rather than a portal —
   and H1 becomes a partner obligation instead of a notification.
3. **Who authors borrower updates?** Already open; H4 makes it urgent, because
   the answer determines whether this actor ever gets a voice.

---

## 4. Story debt summary

1. An actor with no reveals at all, and a declared side effect
   (`notify_borrower_if_visible`) that was never implemented (H1).
2. A stage whose most likely outcome — not funding — has no state, no policy,
   and no story, with 3,989 loans already living in it (H2).
3. A false debt obligation shown to someone who has received nothing (H3).
4. A read-only plane: the person the story is about cannot act in it (H4).
5. Reassurance withheld: lender counts, origins, timelines, and expectations all
   exist or are computable and none reach the borrower (M2, M5).

---

## 5. What would make this compelling

**1. Tell them their loan is live.** The first reveal this actor should ever
receive, at the moment `approve_listing` publishes. It costs a `notify_borrower`
function that does not yet exist, and it converts silence into a relationship.

**2. Answer "is it working?" in the headline.** Replace *"My portal"* with the
state: *"Tu préstamo está al 76% — faltan $225."* State-dependent, and it also
forces H3's fix, because a fundraising loan's headline cannot be a repayment
date.

**3. Show them the people.** *"Fourteen people in six countries have backed you"*
— computable now, and for this actor it is the difference between a progress bar
and evidence that strangers chose them. Faces or flags where the reveal policy
allows.

**4. Deliver the encouragement.** The message is already translated into their
language on approval; it simply is not announced. A reveal plus a thank-you path
closes the product's most human loop, which currently runs one way and stops.

**5. Give the waiting an ending.** Answer Q1, then: a reveal as the deadline
nears, a defined outcome when it passes, and a state that is not "fundraising
since 2023". Even *"this campaign closed without funding, and here is what
happens next"* is infinitely better than three years of silence.

**6. Set expectations on arrival.** "Loans like yours usually fund in about two
weeks" needs only an aggregate over existing data, and it converts an anxious
unknown into a wait with a shape.

**7. Let them speak.** Even one command — thank a supporter, or post an update —
turns a read-only plane into a participant. This is the actor whose voice the
whole product is selling to lenders, and they do not have one.

---

## 6. What is already working (do not regress)

- **Native-language content with an honest fallback badge** — the localization
  model is genuinely built for this actor, when the locale bug does not defeat it.
- **Approved encouragement is machine-translated into the borrower's language**
  before it is shown, rather than shown in the sender's.
- **The funding bar itself** is accurate and legible.
- **Moderation protects them**: unkind, romantic, solicitational, and
  privacy-invasive messages are held before reaching them, with a staff override
  path — a real protection, quietly working.
