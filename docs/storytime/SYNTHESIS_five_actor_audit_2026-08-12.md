# Synthesis — Five Actor Audits, One Product

**Date:** 2026-08-12 · **Series:** visitor · returning lender · waiting borrower
· submitting partner · reviewing staff
**Totals:** 18 HIGH, 33 MEDIUM, 16 LOW findings, and 15 open rulings.
**Subject:** Kredo, an experiment in how far an AI coding agent gets rebuilding a
Kiva-style lending platform.

## Read this twice

This document is doing two jobs, and they pull in different directions.

**As a product report** it is not a release plan. Kredo is a demo and is not
intended to ship. Nothing below is a production incident, and the findings
should not be read as a verdict on the build — the build is genuinely
substantial: five languages as infrastructure, four API surfaces, a hash-chained
provenance trail, one audited mutation path, and 309 passing tests.

**As a demonstration of the StoryTime audit** it is the more interesting
artifact, because the useful question is not *"what is wrong with Kredo?"* but
*"what does this method see that the ordinary methods do not?"* Every finding
below survived a codebase where the tests are green, the code compiles without
warnings, and a careful reviewer had already read most of these files.

---

## 1. The five audits at a glance

| Actor | Their question | Verdict |
|---|---|---|
| **Visitor** | *Should I care?* | Persuasive middle, no way in and no way to finish |
| **Returning lender** | *Did anything happen?* | Given a dashboard when they came for news |
| **Waiting borrower** | *Is it working?* | The only actor with **zero** reveals |
| **Submitting partner** | *What do they need from me?* | Best-served actor; sharp edges |
| **Reviewing staff** | *Can I trust this?* | Best and worst decision surfaces, side by side |

---

## 2. Five patterns that only appear across actors

Any one audit reads as a list of defects. Read together, the same shapes recur —
and the shapes are more informative than the defects.

### Pattern 1 — Declared but inert

The signature finding of this series. Mechanisms that **read as working and do
nothing**, verified one grep each:

| Declaration | Reality |
|---|---|
| `notify_borrower_if_visible` — side effect in the command registry | no such function exists |
| `translations_ready_or_fallback_allowed` — eligibility gate | `def check(...), do: :ok` (fixed 2026-08-11) |
| `risk_summary_present` — approval gate | can never fail; a fallback satisfies it first |
| `:user_return_to` — session key, written on every gated GET | **never read** |
| `fundraising_ends_at` — a deadline on every loan | 13 references, none of them a transition |
| Swoosh mailer — dependency, config, dev mailbox route | `Mailer.deliver` never called |
| "chat-assisted loan application workspace" | documented in three places, built in none |
| `eligibility: []` on 18 of 24 commands | a declared field, left empty |

Eight instances of one class. The common cause is that **a declaration is cheap
and legible while an implementation is neither** — the declaration is the part
that looks like the feature, satisfies a reader, and passes review. This is a
failure mode AI-assisted construction is especially prone to, because fluent
scaffolding is exactly what a model produces most confidently.

It is also the class of defect that conventional review is worst at: a reviewer
reading `eligibility: ~w(translations_ready_or_fallback_allowed ...)` sees a
gate. Only walking the actor's journey and asking *"did the thing actually
happen to them?"* exposes the gap.

### Pattern 2 — The reveal layer is stratified by power, inversely to stake

| Actor | Reveals received |
|---|---|
| Partner (institution) | 2, both directions, carrying reasons |
| Lender (has money at risk) | 5 types, good news only, anonymous |
| Staff (operator) | none — they pull from queues |
| **Borrower (livelihood at risk)** | **zero** |

The actor with the most to lose is told nothing; the institutional actor is told
most. Nobody designed that. It emerged, because each reveal was written next to
the code that triggered it, and no one ever asked *who is downstream of this
event?* — which is Law 4 and Law 5 as a systemic property rather than a local
one.

This is the finding I would show someone who asked what StoryTime is for. It is
a **moral shape in the software** that no test, profiler, or code review would
ever surface, and it is visible only when the same question is asked of five
actors in a row.

### Pattern 3 — Every actor's story ends before its outcome

Law 9 says bail paths are story paths. All five actors have an unmodeled ending,
each in a different disguise:

- **Visitor** — cannot create an account; the funnel has no exit at all.
- **Borrower** — waiting has no defined end. **3,989 of 3,992** fundraising loans
  are past their own deadline, the oldest since June 2023.
- **Lender** — 655 loans completed and none of them a moment; the story's payoff
  is emitted as routine.
- **Partner** — **2,064** drafts and no discard path; nothing can ever be
  abandoned.
- **Staff** — rejecting a translation has no next state, and now permanently
  blocks the loan.

Products are built along the success path because that is the path that gets
demonstrated. StoryTime enumerates exits as first-class stages, which is why five
different missing endings showed up as one pattern rather than five unrelated
bugs.

### Pattern 4 — Surfaces answer the machine's question, not the actor's

Law 23 says a surface answers before it offers. Six headline failures, one per
surface:

| Surface | Says | The actor asked |
|---|---|---|
| Borrower portal | "My portal" | *Is my money coming?* |
| Notification | "A loan you supported received a repayment" | *Who repaid, how much?* |
| Login | "Welcome back" | *How do I sign up?* |
| Submit refusal | "Not ready to submit: `draft_complete`" | *Which field?* |
| Translation queue | a snippet of the target text | *What did the original say?* |
| Admin | analytics first, queues third | *What needs me today?* |

In every case the answering truth was already loaded on the page. This is not
missing data; it is missing **framing** — the cheapest class of fix in the series
and the one that most changes how the product feels.

### Pattern 5 — Scale is an audit instrument

The 1.1M-loan generator was built as a stress-test feature. It turned out to be
the sharpest diagnostic in the series. At 200 loans every one of these is
invisible:

- 679,460 translations awaiting review, queue displays 100
- 3,989 loans past their fundraising deadline
- 164 of one lender's loans in trouble, zero notifications about any of them
- 2,064 permanent drafts
- 957,000 rows rendering a literal `{nombre}` to readers
- 2 of the 3 home-page "fundraising now" loans not fundraising

Story debt hides at demo scale and becomes obvious at real scale. Generating
volume is cheap; **not generating it is what makes an audit optimistic.**

---

## 3. What this method found that the others did not

The honest control group, since all of this coexisted with a healthy codebase:

- **309 passing tests.** Not one of the 18 HIGH findings was visible to them.
  Tests assert that a function does what it says; every finding here is about
  something that was never called, never revealed, or never framed.
- **`mix compile --warnings-as-errors` clean.** Inert declarations compile
  perfectly — a phantom side-effect string is just a string.
- **A performance pass** (done in this same project) found real problems and
  none of these. It measured the paths that exist.
- **Ordinary code review** had already touched most of these files. A gate that
  reads `do: :ok` looks intentional when you are reading the module rather than
  walking the journey.

What made the difference, mechanically:

1. **Walking one actor end to end**, rather than reading one feature at a time.
   The gaps live between features, which is exactly where feature-shaped review
   does not look.
2. **Asking "what does the actor want to know?" before "what does the screen
   show?"** — the ranked question stack turns a vague "this page is thin" into a
   specific, checkable list of unanswered questions.
3. **Grounding in a running instance with real volume**, not just source. Half of
   the strongest evidence in this series is a SQL count.
4. **Treating exits as stages.** Five missing endings, found by asking the same
   question five times.

**What it cost:** five focused sessions, each a code read plus a live walk plus a
handful of queries.

---

## 4. Where this audit series is weak

A demonstration that does not state its own limits is marketing.

- **No practitioner walked any of this.** Every monologue and question stack here
  is derived by an agent from code and cold-reads. Under LSSD's own v1.6
  Practitioner Reality Gate that makes the whole series
  `practitioner_unvalidated` — the seeds are honest guesses at what a borrower or
  a reviewer would ask, not harvested verbatims. A real field-partner officer
  would likely reorder half these stacks in an hour.
- **Observed-reality mining had nothing to mine** (doc 9 §5A). There are no real
  usage logs, so every prominence claim is `estimated`, not `observed`. Where I
  said "the actor's first question is X", that is an inference.
- **Synthetic data can mislead as well as reveal.** The 3,989 expired loans are a
  generator artifact as much as a design gap; what they prove is that *nothing
  would catch it*, not that a real deployment would have 3,989.
- **The auditor built much of the subject.** I wrote some of this code, including
  the publish gate that turned a soft dead-end into a hard block — which I then
  found while auditing. That is an argument for the method and a caution about
  the auditor.
- **Severity is judgement, not measurement.** "HIGH" here means *this breaks the
  actor's story*, not that anything is on fire.

---

## 5. The decision agenda

The most useful output of five audits is not a backlog. It is that **15 open
rulings block most of the work** — the questions have to be answered before the
tickets mean anything. Five of them gate almost everything else:

| Ruling needed | Blocks |
|---|---|
| **What does rejecting a translation mean?** | The staff dead end, and the publish gate's safety |
| **Should loans be able to go bad in the running product?** | The lender's risk story and the product's honesty |
| **What happens when a loan does not fund in time?** | The borrower's ending; 3,989 loans in limbo |
| **Are borrower accounts intended at all?** (1 of 100,203) | Whether the borrower plane is a portal or partner-relayed |
| **Is self-registration in scope?** | Whether the visitor funnel is a bug or a boundary |

The remaining ten: risk-summary authorship, draft retention, chat-first
collection, bulk translation approval, provenance visibility to non-staff,
encouragement sender reveal (ruled, unbuilt), FX modelling, return-cadence for
lender email, repeat lending, `advance_demo_time` guarding.

**If any of it were to be built**, ranked by value per unit of effort rather than
severity:

1. **Put the borrower's name in the reveal.** One string interpolation turns a
   system log into news about a person. (lender H3)
2. **Return the visitor to the borrower they chose.** The mechanism is already
   written and unread. (visitor H2)
3. **Name the missing fields on a refused submit.** The server already evaluated
   all seven. (partner H2)
4. **Answer the top question in each headline.** Six surfaces, all truths already
   loaded. (pattern 4)
5. **Tell the borrower their loan is live.** The first reveal this actor would
   ever receive. (borrower H1)
6. **Show the source text in the translation queue.** One join; converts a guess
   into a judgement. (staff H2)
7. **Give `rejected` somewhere to go.** Needs ruling #1 first. (staff H1)

---

## 6. The one-sentence version

Across five actors, an AI-built product with green tests and clean compilation
was found to have **eight mechanisms that were declared and never implemented, a
reveal layer that speaks in inverse proportion to what each actor has at stake,
and five different unmodeled endings** — none of which any test, compiler, or
conventional review had surfaced, and all of which became visible by walking one
actor at a time and asking what they wanted to know before asking what the screen
showed.
