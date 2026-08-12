# Lender Compendium — Stage Records (Pass 5)

Full records for the 18 `[R]` stages. Every record carries all six decision
categories (an empty one is written `none —` with a reason, never omitted) and a
first-person block: interior monologue in the actor's own voice, plus a ranked
question stack where **every entry names the truth that answers it**.

Monologues are `inferred` — no lender has narrated these. Under the v1.6
Practitioner Reality Gate this whole file is `practitioner_unvalidated`.

---

## `prospective.1.landing`

**Goal:** work out whether this is real and whether they care.
**System goal:** earn enough trust to get them to a borrower.

> *"Loans that change lives. Okay — is this the actual Kiva or something else?
> …'Kredo Demo'. Hm. What does it cost me? Where does my money actually go?"*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Is this real, and whose is it? | product framing | Hero is good; the **first badge says "Demo"** `observed` |
| 2 | What happens to my money? | the 3-step explainer | ✓ accurate and honest `observed` |
| 3 | Do I earn anything? | 0% truth | one click away in the FAQ, not here `observed` |
| 4 | Is anyone else doing this? | scale figures | on `/loans`, not on the page that persuades `observed` |

- **visible_truths:** hero copy, 3 featured loans, how-it-works, locale
- **hidden_relevant_truths:** $1.95B raised, 1.07M active loans (exist, shown elsewhere)
- **available:** browse loans · switch language · sign in · open FAQ
- **blocked:** lend — *not signed in*; **no explanation shown until they click through**
- **hidden:** none — nothing at this stage is policy-hidden from a visitor
- **deferred:** none — no truth is being collected yet
- **askable:** the assistant answers "how does lending work" in `public` role `observed`
- **intentional_silence:** none written; **no analytics on arrival or exit** `observed`
- **loose_ends:** 2 of the 3 featured loans are not fundraising (no status filter) `observed`

---

## `prospective.2.blocked_at_signup` — **terminal**

**Goal:** become a lender.
**System goal:** — *none declared; the product has no answer here.*

> *"Support Salma Haddad. Yes. …'Welcome back'? I've never been here. Where's
> sign up? And where did Salma go?"*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | How do I make an account? | a registration path | **does not exist** `observed` |
| 2 | Am I still helping Salma? | retained intent | **discarded**; `:user_return_to` is written and never read `observed` |
| 3 | Who are these four people? | role personas | demo scaffolding shown to the public `observed` |

- **available:** sign in with credentials they do not have · adopt a demo persona
- **blocked:** register — *no route exists*; **no explanation, because nothing knows it should**
- **hidden:** none
- **deferred:** none
- **askable:** none — the assistant cannot create an account either
- **intentional_silence:** none written. The exit is unlogged.
- **reveal edges on commit:** none — nothing commits
- **loose_ends:** this is the terminal stage of four unreachable bands

---

## `individual.3.choosing`

**Goal:** find one borrower worth backing.
**System goal:** make the choice legible and fast at 3,992 candidates.

> *"Jordan. Sewing school uniforms. $425 to go — I could actually finish this
> one. What happens if she doesn't pay it back?"*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Who is this and what do they need? | photo, name, story, use | ✓ **the best surface in the product** `observed` |
| 2 | How close are they? | funded %, remaining | ✓ framed as *remaining* — creates agency `observed` |
| 3 | What is my risk? | risk summary, trust model | on the full profile, **absent from the drawer where the decision happens** `observed` |
| 4 | What do I do? | the CTA | ✓ "Support Salma Haddad" `observed` |

- **visible_truths:** photo, name, country, sector, story, use, funded %, remaining, lender count, days left
- **hidden_relevant_truths:** the provenance trail (staff-only) — the strongest proof this person is real `observed`
- **available:** open drawer · view full profile · add to basket · lend now · filter/search · switch language
- **blocked:** lend — *if not a lender role*; explanation is inline with demo credentials `observed`
- **hidden:** partner risk notes; other lenders' identities
- **deferred:** lend → needs amount (defaults $25)
- **askable:** "show me loans in Kenya", "what's almost funded" — Ask Mode `observed`
- **intentional_silence:** browsing is not revealed to the borrower — **correct and deliberate** (attention ≠ commitment)
- **loose_ends:** searching a 3-char term matched inside other words until 2026-08-11; risk absent from the drawer

---

## `individual.3.confirming`

**Goal:** commit money without fear of a mistake.
**System goal:** one audited mutation path, with a preview.

> *"$25. Or $50? …It says no real money moves. Fine. Confirm."*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Exactly what am I about to do? | the preview | ✓ amount + borrower named `observed` |
| 2 | Can I undo this? | reversal policy | **no undo exists, and nothing says so** `observed` |
| 3 | Is this real money? | demo disclaimer | ✓ stated at the moment of commitment `observed` |

- **available:** choose amount ($25 increments) · lend as self or team · confirm · cancel
- **blocked:** amounts not in $25 units — *server-enforced* (`lend_amount_valid`) and the client quotes it `observed`
- **hidden:** the funded-total recalculation; the $25-unit snapping of the loan's funded figure
- **deferred:** none — every required truth is present at this point
- **askable:** "lend $50 to weaving" → preview + confirm through the same command `observed`
- **intentional_silence:** the borrower is **not** told an individual lent — only aggregate funding
- **reveal edges on commit:** → loan funded% (public) · → lenders on full funding · → **borrower: nothing** `observed`
- **loose_ends:** no undo, no cooling-off, no written silence explaining either

---

## `individual.4.awaiting_full_funding` — band 4

**Goal:** find out whether the loan they backed made it.
**System goal:** close the loop on a commitment.

> *"79% when I lent. Did it get there? Nobody's told me anything."*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Did it fully fund? | `loan_funded` reveal | ✓ **the one reveal that fires here** `observed` |
| 2 | How long will it take? | typical time-to-fund | **no such truth anywhere** `observed` |
| 3 | What if it doesn't? | expiry policy | **undefined**; 3,989 loans past deadline `observed` |

- **available:** view the loan · lend more · encourage (if lender) · browse away
- **blocked:** cancel my lending — *no such command exists*; **no explanation** `observed`
- **hidden:** which other lenders are in
- **deferred:** none
- **askable:** "how's my loan doing" — answerable only per-loan
- **intentional_silence:** partial-funding progress is **not** revealed per-increment — sensible, unwritten
- **loose_ends:** the "it never funds" branch has no state, no reveal, no policy (storm S3)

---

## `individual.4.awaiting_repayment` — band 4, the long one

**Goal:** know their money is coming back.
**System goal:** report repayment truthfully.

> *"Seven repayments since I last looked. From who? …It just says 'a loan you
> supported'. Which one?"*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Who repaid and how much? | borrower + amount | **neither is in the reveal** `observed` |
| 2 | Is anything behind? | delinquency reveal | **never sent**; 164 of the demo lender's loans are in trouble, 0 notifications `observed` |
| 3 | How much is back? | available-to-relend | ✓ on the portfolio `observed` |

- **available:** view portfolio · view a loan · relend · encourage
- **blocked:** none — nothing is legally blocked at this stage
- **hidden:** the schedule's interest portion (belongs to the partner, correctly withheld)
- **deferred:** none
- **askable:** "my impact" `observed`
- **intentional_silence:** per-installment emails — **silent by absence, not by decision** (no channel exists)
- **loose_ends:** reveal carries no identity; no channel reaches them off-site

---

## `individual.4.loan_in_trouble` — band 4, the missing one

**Goal:** learn that something went wrong.
**System goal:** — *none. No code path produces this stage.*

> *"…"* — **the actor is never in this stage, because they are never told they
> are.**

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Is one of mine in trouble? | delinquency/default reveal | **no live code sets either status** `observed` |
| 2 | How much have I lost? | loss attribution | ruled in 2026-08-11, **unbuilt** `asserted` |

- **available:** filter the portfolio by delinquent/defaulted — *if they think to*
- **blocked:** none
- **hidden:** **unintentionally** — trouble is discoverable but never revealed
- **deferred:** none
- **askable:** none that would surface it
- **intentional_silence:** **NOT intentional.** This is silence by omission — the trust-killer (L16)
- **loose_ends:** the portfolio prints "Behind schedule: $22,396" as though the lender already knew

---

## `individual.5.fully_repaid` — the payoff

**Goal:** feel the ending.
**System goal:** close the story.

> *"She actually paid it all back. …Did she? It says 'repayment received' again."*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Did this one finish? | a completion reveal | **none — same generic string as installment 3 of 14** `observed` |
| 2 | What did it add up to? | lent vs returned per loan | on the portfolio row, never announced `observed` |
| 3 | What happened to her? | borrower outcome update | exists per-loan; **no feed** `observed` |

- **available:** relend the returned capital · view the loan
- **blocked:** thank the borrower — *no command exists* `observed`
- **hidden:** none
- **deferred:** none
- **askable:** none
- **intentional_silence:** none written; the silence here is the biggest unspent moment in the product (655 completions for one lender)
- **loose_ends:** completion sets `status: "completed"` and emits nothing distinct

---

## `individual.6.portfolio` — steady state

**Goal:** see what their money did.
**System goal:** answer the lifetime question honestly.

> *"$139,975 across 1,408 loans. 66% back. …And the rest?"*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | What has my money done? | hero: lent, repaid, borrowers, countries | ✓ **exemplary; answers before it offers** `observed` |
| 2 | What can I do now? | relend banner | ✓ one action, stated in money `observed` |
| 3 | What have I lost? | loss breakdown | **absent**; details page ruled in, unbuilt `asserted` |
| 4 | Where's that one borrower? | text search | **absent** across 1,408 `observed` |

- **available:** filter/group by country, status, sector, partner · view chart · relend · page
- **blocked:** none
- **hidden:** other lenders' portfolios
- **deferred:** none
- **askable:** "my impact", "what's behind schedule"
- **intentional_silence:** none needed — this is a self-view
- **loose_ends:** 244–281ms per query at scale; repayment scaffolding renders on fundraising rows

---

## `individual.6.relending` — the loop

**Goal:** put returned money back to work.
**System goal:** convert idle capital into a new loan.

> *"$92,840 sitting there. Who needs it? …Same as last time, I suppose."*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | How much do I have? | available-to-relend | ✓ in money, with one button `observed` |
| 2 | Who should I back? | a suggestion | **dropped at an unpersonalised list of 3,992** `observed` |
| 3 | Can I back the same people again? | borrower history | **no repeat path, no "my borrowers"** `observed` |

- **available:** click through to `/loans` · filter manually
- **blocked:** none
- **hidden:** none
- **deferred:** none
- **askable:** "lend $50 to weaving" — the assistant does understand this intent `observed`
- **intentional_silence:** none
- **loose_ends:** convergence failure — one lived moment split across two surfaces, the second knowing nothing about the first

---

## `individual.7.returning` — band 7

**Goal:** find out what changed while away.
**System goal:** — *none declared.*

> *"It's been a few weeks. Did anything happen? Did Salma finish?"*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | What changed since I left? | a since-marker | **no such truth**; `read_at` exists, nothing frames an interval `observed` |
| 2 | Anything need me? | ranked attention | flat list of 30, no grouping `observed` |
| 3 | Did anything go wrong? | trouble reveal | never `observed` |

- **available:** read notifications · mark all read · view portfolio
- **blocked:** none
- **hidden:** none
- **deferred:** none
- **askable:** none framed around the interval
- **intentional_silence:** none written
- **loose_ends:** storm S12 (stale truths on return) is entirely unhandled

---

## `basket.3.assembling`

**Goal:** back several borrowers in one sitting.
**System goal:** hold intent safely until commitment.

> *"Three of these. Maybe four. I'll decide the total at the end."*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | What's in here and what's it cost? | count + total | ✓ `Basket.count/1`, `total_cents/1` `observed` |
| 2 | Will these still be available? | per-loan status at checkout | **not re-checked in the basket view** `inferred` |
| 3 | How long can I leave it? | basket lifetime | **forever — no expiry, no scheduler** `observed` |

- **available:** add · remove · clear · checkout · keep browsing
- **blocked:** adding a non-fundraising loan — server-enforced (`loan_fundraising`) `observed`
- **hidden:** none
- **deferred:** checkout → needs per-item amounts (defaulted)
- **askable:** none — the assistant has no basket command `observed`
- **intentional_silence:** basket contents are **not** revealed to borrowers — correct (intent ≠ commitment)
- **loose_ends:** a loan can fully fund while sitting in someone's basket; storm S7

---

## `basket.3.checkout`

**Goal:** commit to all of them at once.
**System goal:** one act → N audited lendings.

> *"Four borrowers, $100. Go."*

- **available:** confirm all · cancel
- **blocked:** items whose loan left fundraising — *eligibility runs per item* `observed`
- **hidden:** the per-loan funded recalculation
- **deferred:** none
- **askable:** none
- **intentional_silence:** no basket-level receipt is revealed to anyone
- **reveal edges on commit:** → each loan's funded% · → lenders of each loan **only if it crosses to fully funded** · → **borrowers: nothing**
- **loose_ends:** after checkout the basket dissolves — **no basket-level record survives**, so "the four I backed together" is unreconstructable; partial failure across items is unmodelled (storm S8)

---

## `team.2.creating`

**Goal:** lend alongside other people.
**System goal:** create a durable group artifact.

> *"The Coffee Fund. Public. …Now how do I get anyone into it?"*

- **available:** name it · set visibility · create
- **blocked:** none
- **hidden:** slug uniquification
- **deferred:** none
- **askable:** none
- **intentional_silence:** creating a team reveals to nobody
- **loose_ends:** **the founder is the only member the system can ever create** (`teams.ex:48`); a "team" is a single-person artifact unless seeded

---

## `team.3.lending_on_behalf`

**Goal:** have the loan counted toward the team.
**System goal:** attribute a lending to a group.

> *"Put this one under the Coffee Fund."*

- **available:** lend as self · lend as team (choose from teams they belong to)
- **blocked:** lending on behalf of a team they are not in — *not enforced by any named check* `observed` (`lend/4` takes `team_id` and only verifies the team exists)
- **hidden:** none
- **deferred:** none
- **askable:** "lend $50 to weaving with my team" — the intent parses `observed`
- **reveal edges on commit:** → team total updated · → **team members: nothing** (no team-activity reveal exists)
- **loose_ends:** eligibility gap — team membership is not checked at lend time

---

## `encourager.3.writing`

**Goal:** say something to the person they backed.
**System goal:** protect the borrower from harm before delivery.

> *"I want her to know someone's rooting for her. Is she going to see this in
> Arabic or English?"*

| # | Question | Answered by | Today |
|---|---|---|---|
| 1 | Will she understand it? | translation behaviour | **not stated at compose time** `observed` |
| 2 | Will she know it's me? | sender reveal policy | ruled public-profile-gated 2026-08-11, **unbuilt** `asserted` |
| 3 | Can she reply? | reply path | **none exists** `observed` |

- **available:** write · submit
- **blocked:** encouraging a loan they did not back — *not enforced*; `submit_encouragement_message` gates only on `loan_exists` `observed`
- **hidden:** the moderation rubric
- **deferred:** submit → needs body + source locale
- **askable:** the assistant offers a kinder rewrite when moderation objects `observed`
- **loose_ends:** the writer is never told the message was delivered

---

## `encourager.4.awaiting_moderation`

**Goal:** know their words reached her.
**System goal:** hold anything unkind before it lands.

> *"Did that go through? …It just went quiet."*

- **available:** write another
- **blocked:** editing a held message — *no such command* `observed`
- **hidden:** that staff are reviewing it, and why it was held
- **deferred:** none
- **askable:** none
- **intentional_silence:** a blocked message's *reason* is withheld from the sender — **plausibly deliberate, nowhere written**
- **reveal edges on commit:** approved → borrower sees it translated; → **sender: nothing, ever** `observed`
- **loose_ends:** the declared side effect `notify_borrower_if_visible` has no implementation

---

## `developer.3.reading`

**Goal:** get their portfolio out programmatically.
**System goal:** honour API parity without opening write access.

> *"`/v1/my/loans.json`. Good. Now can I lend from here? …No mutations."*

- **available:** read loans, teams, lender, expected repayments (v1 + v2 + both GraphQL surfaces)
- **blocked:** lending via API — **structurally: no mutation exists in either schema** `observed`; no error explains it, the capability simply is not described
- **hidden:** other lenders' data (API-key scoped)
- **deferred:** none
- **askable:** the docs assistant generates a call in six languages `observed`
- **intentional_silence:** rate limits — none exist, none stated
- **loose_ends:** `capability_manifest` is served at `/developers/agents.md`, yet an agent reading it finds no way to act — **agent parity fails on the write side**
