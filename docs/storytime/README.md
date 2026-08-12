# StoryTime Audits — What This Folder Is

This folder holds **actor-journey audits** of Kredo: one per role, plus a
synthesis and a full enumeration of the lender's journeys. They were produced
with a methodology called **LSSD**, and they are the reason this repository is
worth browsing even though the app itself is a demo.

If you arrived here from somewhere else and want the short version:

> Kredo is an experiment — how much working product can a handful of AI-assisted
> sessions actually produce? The answer was **about 8.6 hours** for a
> five-language lending platform with four API surfaces. These documents are what
> happened when that thing was then audited **as a set of human journeys** rather
> than as a set of features. The tests were green and the compiler was clean
> throughout. The audits found 18 high-severity gaps anyway.
>
> Both halves matter. Software can now be produced faster than the methods we
> normally use to check it. These reports are one answer to the second problem.

**Nothing here was implemented.** These are findings, deliberately kept separate
from fixes.

### Two things to be clear about up front

**All of this is AI-run.** The product was written by an AI agent. The audits
were run by an AI agent. The lender compendium was enumerated by one and
criticised by another in fresh context. A human directs the work, makes the
product rulings, and corrects the record — but no human wrote this code, and no
human wrote these reports. That is the experiment. Where the machine's judgement
is the weakest link, the documents say so in the text rather than hoping you
won't ask.

**Kredo is not a finished product and these reports do not pretend otherwise.**
It is a demo built in a handful of sittings, published deliberately unpolished.
The audits are an honest inventory of what is missing from it — including things
the same AI got wrong days earlier, published unedited. A report that only found
small problems in its author's own work would not be worth reading.

---

## What LSSD is

**Living Systems Software Development.** A methodology for building and
maintaining software in which the product is treated as *a set of interwoven
human stories*, not a database with screens attached.

The core claim is simple: a record — a loan, a booking, an order, a ticket — is
not the story. It is a by-product of decisions made inside many overlapping
stories, by people with different information, different power, and different
things at stake. Software fails at the seams between those stories, and
feature-shaped review does not look at seams.

It is used in five modes:

| Mode | What it does |
|---|---|
| **Spec from scratch** | Turn an idea into a buildable specification, enumerated before any screen is drawn |
| **Build** | Drive implementation from that specification, in story-sized slices |
| **Add on** | Extend an existing product without tearing the existing journeys |
| **Compendium** | Exhaustively enumerate every actor, journey, decision, and failure path in a domain — the main idea-generating mode |
| **Audit** | Examine an existing product and codebase for gaps in the experience it delivers, and for the features its own data is already asking for |

This folder is mostly the fifth mode, with one example of the fourth
(`compendium_lenders/`).

**FractalFlow** is the contract language LSSD projects from — the `.lssd.md`
files under `docs/fractalflow/`. Its grammar is out of scope here; you do not
need it to read these audits.

---

## What these reports produce

The method has two outputs, and the second is the one most people underestimate.

Kredo took roughly 8.6 hours to build. Auditing it properly took another 7. That
ratio is the point: when a working product can be assembled in a few sittings,
the binding constraint stops being construction and becomes **knowing what you
actually built**. Tests tell you the code does what it says. They cannot tell you
that a person's story ends halfway through.

---

## Output 1 — features nobody had thought of

This is the primary reason to run it. The audits in this folder produced **39
concrete product proposals** and **19 open product questions**, almost none of
which are bug fixes. A sample of what came out of a codebase its own author knew
well:

- **"Fourteen people in six countries have backed you."** A borrower waiting for
  their loan to fund sees a progress bar. That sentence is computable from data
  already loaded, and for the person whose livelihood is at stake it is the
  difference between a metric and evidence that strangers chose them. Nobody had
  considered showing it.
- **Full repayment as a moment.** One lender in this database has had 655 loans
  repaid in full and was never once told a story finished — each final payment
  emits the same string as installment 3 of 14. That is 655 unspent emotional
  payoffs per lender, and the fix is a distinct message with the borrower's photo
  and a one-tap relend.
- **"Your $25 buys the cloth for eight uniforms."** The loan-use text already
  exists; the missing move is arithmetic against the lending increment.
- **A "your borrowers" view.** The portfolio slices by country, status, sector,
  and partner — every dimension except the human one that made someone lend.
- **Edit-and-approve.** Translation review offers approve or reject. Most real
  review work is *correction*, and the middle response did not exist as a concept
  anywhere in the product.

It also finds **whole categories of user nobody had modelled**. Enumerating the
lender plane surfaced fourteen distinct lender types; several existed in the
running product and in nobody's mental model:

| Discovered actor | Why it was invisible |
|---|---|
| The lender **authorising a third-party app** | Conflated with the developer who *built* the app. Consent, denial, grant review, and revocation are all absent. |
| The **third-party app itself** | Holds a token against someone's account, with no story for expiry, compromise, or what data it keeps afterwards. |
| The **high-volume lender** | 1,408 lendings exists in the data; no journey is designed for it — no search, notifications capped at 30. |
| The assistant being **confidently wrong** | Outages and refusals were handled. Being plausibly incorrect about someone's money was not. |

Some of what it proposes is **net-new product** — capabilities the system has no
data for, no model of, and no code near:

- **Telling a borrower anything at all.** The reveal layer has no borrower plane;
  the function to notify one does not exist. Building it is a new channel, not a
  new screen.
- **A thank-you path.** A borrower cannot reply to the stranger who funded them.
  That is a new command, a new artifact, a new moderation question, and a new
  reveal edge — none of which the product contains.
- **An ending for a loan that never funds.** 3,989 loans sit past a deadline
  nothing enforces. Giving that an outcome means new states, a new policy, a
  scheduler that does not exist, and reveals to three different actors.
- **Currency-exchange loss.** The lender risk breakdown wants it. The product is
  all-USD and has no concept of it whatsoever — the feature would introduce a
  domain concept, not surface a hidden column.
- **Recurring lending.** Surfaced as an entire missing actor: nobody had asked
  whether a lender might want to commit monthly.

### Why it generates ideas instead of just opinions

Two mechanisms, and they pull in opposite directions on purpose.

**A combinatorial sweep, not a brainstorm.** Every actor is walked through seven
life stages; every stage is examined for six categories of decision; every actor
is then run against fourteen standard ways things go wrong. That grid has
thousands of cells and any real product leaves most of them empty. An empty cell
is one of two things: a deliberate decision, written down — or a feature nobody
thought of. Forcing every cell to be one or the other is what produces the list.

**The story forces the schema.** The method writes what an actor should
experience *before* checking whether the system can support it — in the actor's
own voice, as a scene. When a sentence in that scene needs a fact the product
does not have, the sentence wins: the missing fact is filed backward as a
requirement. This is a formal step, not a happy accident, and it is how the
method escapes the gravity of the existing database.

Three truths in this repository's contracts exist **only** because a scene
demanded them and the schema did not have them: a lender-controlled
`profile_public` flag (so a borrower can learn who backed them), per-loan loss
attribution, and arrears aging. None were in anyone's data model. All three are
now specified requirements because someone wrote what the moment should feel
like and the moment needed them.

The combination is what matters. The sweep guarantees coverage — you will not
miss an actor or a failure mode. The screenplay guarantees ambition — you are not
limited to rearranging what you already store.

---

## Output 2 — gaps you cannot see from inside

The other half is what the product asserts versus what it does. Everything in
these reports coexisted with:

- **309 passing tests** — not one of the 18 high-severity findings was visible to them
- **a clean `--warnings-as-errors` compile**
- **a prior performance pass** that found real problems and none of these
- **ordinary code review** that had already read most of the same files

That is possible because the defects are not in the code that exists. They are in
code that was *declared and never written*, in events that happen and are never
told to anyone, and in journeys that stop before the person reaches an outcome.

A representative example from this repository: a high-risk approval gate was
declared in the command registry and had shipped for months as

```elixir
def check("translations_ready_or_fallback_allowed", _actor, _params), do: :ok
```

It read as enforced in every review. It enforced nothing. Eight mechanisms in
this codebase turned out to be of that kind.

### If you are evaluating someone else's codebase

Several findings here are the technical form of *"everything is working"* when
it is not — the failure mode that survives a status update and a demo:

| What the audit found | What it would look like from the outside |
|---|---|
| A gate declared, implemented as `:ok` | A compliance control that reviews as present |
| A public risk disclosure autogenerated and attributed to a human reviewer | A human-attested statement no human wrote |
| Two stored numbers for the same money disagreeing on 7,219 records, with nothing able to detect it | Reconciled figures, until someone reconciles them |
| 3,989 records past a deadline no code enforces | An expiry policy that exists only in the UI copy |
| Notifications carrying only good news, while 164 of one user's holdings were in trouble | A healthy-looking dashboard |
| ~957,000 rows rendering a literal `{nombre}` placeholder to end users | Localized content, at a glance |

None of those are lies anyone told. They are what happens when a declaration is
cheaper than an implementation and nothing walks the user's path end to end.

An audit like this is a **codebase-grounded review of delivered experience**. It
is not a financial audit, a security assessment, or a penetration test, and it
does not verify business claims. What it does is compare what a product asserts
it does against what its code and data actually do for each person involved.

---

## What is in here

| File | What it covers |
|---|---|
| `SYNTHESIS_five_actor_audit_2026-08-12.md` | **Start here.** The five audits read together: cross-cutting patterns, the honest control group, and where the method is weak |
| `visitor_first_visit_audit_2026-08-12.md` | A stranger arriving, browsing, and trying to help |
| `returning_lender_audit_2026-08-12.md` | Someone who already lent, coming back |
| `borrower_awaiting_funding_audit_2026-08-12.md` | The person whose loan has not funded yet |
| `partner_loan_submission_audit_2026-08-12.md` | The field partner entering and submitting a loan |
| `staff_review_queues_audit_2026-08-12.md` | Staff working the review queues |
| `dashboard_first_person_audit_2026-08-10.md` | The four logged-in dashboards, audited together |
| [`compendium_lenders/`](compendium_lenders/) | A full enumeration of every lender type and journey — 14 actors, 67 stages, 28 walks, 19 open questions. The **idea-generating** mode rather than the audit mode |
| [`grammar_upgrade_report_2026-08-10.md`](grammar_upgrade_report_2026-08-10.md) | Internal: bringing the contract layer up to current LSSD grammar |

The five actor audits share a structure: the actor's journey, their first-person
question stack, findings by severity with code citations, a story-debt summary,
**what would make it compelling**, and what already works and should not
regress. The synthesis reads them together.

Inside [`compendium_lenders/`](compendium_lenders/):

| File | Contents |
|---|---|
| [`00_scope_and_cast.md`](compendium_lenders/00_scope_and_cast.md) | The 14-plane sweep and the 14 lender actors it named or ruled out |
| [`01_ladders.md`](compendium_lenders/01_ladders.md) | Every actor's life stages across seven bands |
| [`02_stage_records.md`](compendium_lenders/02_stage_records.md) | 18 full stage records with interior monologues and question stacks |
| [`03_walks_and_storm.md`](compendium_lenders/03_walks_and_storm.md) | 28 consequence walks and the 14-family failure storm |
| [`04_reveals_artifacts_details.md`](compendium_lenders/04_reveals_artifacts_details.md) | Reveal edges, the communication catalog, artifact and detail stories |
| [`05_matrices_counts_gates.md`](compendium_lenders/05_matrices_counts_gates.md) | Matrices, the count block, the gate report, and 19 open questions |

---

## The other documentation directories

| Directory | What it holds |
|---|---|
| [`../fractalflow/`](../fractalflow/) | **The living contracts** — ten documents modelling the system's actors, truths, commands, policies, and reveals, kept in sync with the code. These audits are projected from them. |
| [`../prd/`](../prd/) | **The original planning corpus** — 18 documents written before any code existed. Preserved unedited; superseded by the contracts. Reading them beside these audits shows the full arc: planned → built in ~8.6 hours → audited → gaps found. |
| [`../kiva_api_compatibility.md`](../kiva_api_compatibility.md) | How the Kiva-compatible API surfaces map to the real ones |

---

## Glossary

The terms below appear constantly in these documents and mean something specific.

### The shape of a story

**Actor** — a person or system with their own view, their own permissions, and
their own stake. Not a "user type": the same human at a different point in their
story (first visit vs. returning after a year) is a different actor.

**Actor plane** — one actor's complete view of the product. The same loan looks
different in the borrower's plane, the lender's plane, and staff's.

**Stage** — one moment in an actor's journey, with a defined entry and exit.
*"Waiting for my loan to fund"* is a stage. Stages are what the person lives.

**Ladder** — the ordered set of stages for one actor, covering their whole
relationship with the product from first contact to leaving.

**Band** — one of the seven sections every ladder must cover: (1) discovery,
(2) setup, (3) committing, (4) **waiting**, (5) the event and its aftermath,
(6) steady state, (7) exit and return. Band 4 is the most commonly skipped in
real products, and band 7 the most commonly forgotten. A band with no stages
must be ruled out *in writing*.

**Journey vs. lifecycle** — a lifecycle is what the machine does to a record
(`draft → submitted → approved`). A journey is what a person lives. Building
screens from the lifecycle produces one-button-per-database-state interfaces.
The two are not the same thing and the distinction is load-bearing.

### What a person can see and do

**Surface** — anywhere the product speaks to an actor: a page, a panel, an email,
a notification, a chat reply. Used in preference to "screen" because most
surfaces are not screens.

**Truth** — a fact the product holds. Truths are tracked by *who they are visible
to*, *who has authority over them*, and *how confident we are* — a fact can be
reliable for one purpose and not another. When a document says a surface
"withholds a truth," it means the fact exists in the system and is not shown to
someone who needs it.

**Affordance** — something the actor can actually do at this stage.

**Decision categories** — every stage classifies each possible action as one of
six: **available** (can do now), **blocked** (can't, and should be told why),
**hidden** (must not know it exists), **deferred** (needs more information
first), **askable** (can be asked in words), or **intentional silence**
(deliberately not offered). Leaving a category out is treated as forgetting;
writing "none, because…" is the discipline.

### How information moves between people

**Reveal** — a truth crossing from one actor to another: a notification, an
email, a status change the other side can see. Reveals are the connective tissue
of a multi-actor product and the most common thing missing from one.

**Reveal edge** — one specific crossing: *this event → that actor → through this
channel → in their language*.

**Written silence** — a deliberate, recorded decision **not** to tell someone
something. The point of the term is the difference between choosing silence and
merely forgetting. In this repository, 9 of 13 lender reveal edges were silent
and **none** of the silences had been decided.

**Under-reveal / overexposure** — the two failure directions: someone needs a
fact to act and does not get it; or someone sees a fact they should not.

### Things the product keeps

**Artifact** — anything the product creates and stores: a loan, a message, a
draft, an uploaded photo, a chat transcript. Every artifact needs a full story:
who makes it, who sees it, how it changes, how long it is kept, and how it is
deleted. *"No artifact without a story"* — an artifact with no deletion path is a
finding.

**Detail story** — the same treatment applied to a single field, for fields that
carry risk. Where did this value come from, who may change it, how confident are
we, and who is allowed to see it?

**Bail path** — what happens when someone abandons: closes the tab, never
returns, walks away mid-form. Every exit is a real state that creates or orphans
data. Products are built along the success path, so bail paths are where the
debris collects.

### The audit machinery

**Compendium** — the exhaustive enumeration: every actor, every stage, every
decision, every failure path, written down before anything is designed. It is
deliberately large. `compendium_lenders/` is a worked example.

**Consequence walk** — following one action all the way through: what command
runs, what must be true first, what changes, who gets told, and how it can fail.

**Scenario storm** — running fourteen standard failure families (abandonment,
rejection, expiry, cancellation, collision, partial failure, dispute, ghosting,
first-run, returning, admin intervention, deletion…) against every actor. *"A
storm that yields nothing wasn't run."*

**Command / command registry / eligibility** — the single audited path through
which state may change, and the named preconditions each change requires. If a
button mutates data outside that registry, that is a finding regardless of
whether it works.

**Question stack** — the ranked list of what an actor actually wants to know at a
given moment, each entry naming the truth that would answer it. It converts a
vague "this page feels thin" into a checkable list.

**Interior monologue** — the same moment written in the actor's own voice,
present tense. *"Did it go through?"* — never *"the user wants to know the
status."* If it cannot be written in character, the stage is not understood yet.

**Story debt** — the accumulated cost of stories that were never enumerated:
silent state changes, orphaned artifacts, missing reveals, unmodelled endings.
Like technical debt, but measured in what people experience.

### Confidence and honesty

**Evidence labels** — every claim in these documents is marked:

- `observed` — proven in the code or the data, with a citation
- `asserted` — declared in a contract or ruling, but not built
- `inferred` — reasoned, and not proven

**Gates (G1–G6)** — completeness checks each pass must clear. A gate is either
passed or declared unmet with a count. In `compendium_lenders/` two are marked
PARTIAL rather than claimed.

**Practitioner gate / `practitioner_unvalidated`** — the honesty marker that
matters most here. **No real borrower, lender, partner, or reviewer narrated any
of this.** Every interior monologue in these documents is a well-informed guess
by an agent reading code. Under LSSD's own rules that makes the whole series
provisional until a real practitioner walks it, and it is labelled as such
throughout.

**Severity** — 🔴 HIGH breaks the actor's story · 🟡 MEDIUM leaves them confused
or unserved · 🟢 LOW is polish · ❓ QUESTION needs a human decision before any
work is meaningful.

---

## What this method does not do

- It does not test correctness. Use tests for that.
- It does not measure performance, though it often points at where to look.
- It does not verify security, compliance, or financial claims.
- It cannot replace talking to real users. Everything here is
  `practitioner_unvalidated` — derived from code and cold-reads, not from people.
- **The feature proposals are hypotheses, not validated demand.** Each is
  grounded — it answers a question a specific actor is provably left with — and
  they range from surfacing something you already store to building a capability
  from nothing. But "this person has no way to learn X" is an argument, not
  evidence that shipping X will matter to them. The method finds the candidate
  set fast and cheaply, and sizes nothing; deciding which ones are worth building
  is still your job, and still needs users.
- Its severity ratings are judgement, not measurement.

The most useful output of the five audits in this folder was not a backlog. It
was **fifteen open questions** — decisions only a product owner can make, which
had to be answered before any of the work meant anything.

---

## Consulting & implementation

I'm **Paul Ericksen**. I build with this methodology and I run these audits on
other people's products.

- **Journey audits** — a report like the ones in this folder, for an existing
  product and its codebase: the features your data is already asking for, where
  the experience breaks, what was declared and never built, and which decisions
  are blocking the rest.
- **Feature discovery** — the compendium run against a product you already have,
  to find the users and journeys nobody has modelled yet. This is usually the
  highest-value engagement and the one people do not expect.
- **Compendiums** — exhaustive enumeration of a domain's actors and journeys
  *before* you build, so the expensive omissions are found on paper.
- **Spec and build** — new products, or additions to existing ones, developed
  story-first and implemented by AI under the same methodology that produced
  this repository.
- **Team enablement** — running the method with your own people so it outlives
  the engagement.

The work is AI-executed and human-directed, which is what makes the economics
unusual: the enumeration above cost hours, not weeks.

Kredo itself, the repository this folder sits in, was built with these methods
end to end and then audited by them — including findings about work I had done
days earlier, which are published here unedited.

**Get in touch:** open an issue on this repository, or reach me through my
GitHub profile — [@nuclearspike](https://github.com/nuclearspike).
