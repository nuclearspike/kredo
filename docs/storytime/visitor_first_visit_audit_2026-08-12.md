# StoryTime Audit — The New Visitor's First Visit

**Date:** 2026-08-12 · **Actor:** a member of the public who has heard of Kiva
and typed the address in. No account, no context, no prior relationship.
**Scope:** every surface reachable without signing in — `/`, `/loans`,
`/loans/:slug`, the browse drawer, `/teams`, `/faq`, `/partners/:slug`,
`/login`, and the assistant in its `public` role.
**Method:** code read of the public surfaces plus a logged-out walk of the real
site at demo scale (1,100,205 loans), following the path an interested stranger
actually takes: land → browse → pick someone → try to help.
**Deliverable:** audit only. Nothing here was implemented.

**Verdict in one line:** the middle of this journey is genuinely good — the
browse drawer is the most persuasive thing in the product — but it begins by
announcing it isn't real and ends at a wall with no door, because a visitor
cannot create an account and the borrower they chose is thrown away when they
try.

---

## 1. The journey, as it exists

| # | Stage | Surface | What happens |
|---|---|---|---|
| 1 | Arrival | `/` | Hero, three featured borrowers, "How it works", demo-account table |
| 2 | Browsing | `/loans` | 3,992 fundraising loans, status/sector filters, search |
| 3 | Considering | drawer | Photo, progress, "$425 to go", story, one clear CTA |
| 4 | Deciding | `/loans/:slug` | Full profile, trust & verification, repayment schedule |
| 5 | Committing | `/login` | **Dead end** |

Stages 2–4 are strong. Stages 1 and 5 are where this actor is lost.

---

## 2. First-person layer (v1.12 seeds)

No stage in the contracts carries a monologue or question stack for this actor.
Derived here from the walk; these are the seeds if the visitor journey is ever
formalised.

### Stage 1 — Arrival
> *"Is this the real Kiva? What is this? Does my money actually reach anyone,
> or is this one of those sites? What does it cost me?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | What is this and is it real? | product framing | Hero says "Loans that change lives" — good — but the **first element is a "Kredo Demo" badge**, which answers "is this real?" with "no" |
| 2 | What happens to my money? | the 3-step explainer | ✓ "Choose a borrower → Lend $25 → Get repaid, relend" is clear and honest |
| 3 | Does it cost me anything / do I earn? | 0%-interest truth | Absent from the home page; lives one click away in the FAQ |
| 4 | Is anyone actually using this? | scale/credibility | **Absent.** $1.9B raised and 1.1M loans are on `/loans`, not on the page that has to convince |
| 5 | Who runs this? | — | **No answer anywhere.** No about, no team, no accountability |

### Stage 3 — Considering a specific borrower (the drawer)
> *"Salma. Jordan. Sewing school uniforms. $425 to go — that's not much. Could I
> actually finish this? What happens if she doesn't repay?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | Who is this person and what do they need? | photo, name, story, "how this money helps" | ✓ **Excellent.** The single best surface in the product |
| 2 | How close are they? | funded %, "$425 to go" | ✓ Framed as remaining, not raised — the right framing |
| 3 | What's the risk to me? | risk summary, trust model | Present on the full profile, absent from the drawer where the decision is made |
| 4 | What do I do now? | the CTA | ✓ "Support Salma Haddad" — personal, unambiguous |

### Stage 5 — Committing
> *"Yes. Salma. …Wait, why am I looking at a login form? I don't have an
> account. Where did Salma go? What are all these other people — borrower,
> partner, admin?"*

| # | Question | Answering truth | Today |
|---|---|---|---|
| 1 | How do I sign up? | a registration path | **Does not exist** (H1) |
| 2 | Am I still supporting Salma? | retained intent | **No.** She is gone from the page and from the session (H2) |
| 3 | Why does it say "Welcome back"? | — | Greets a first-time visitor as a returning user (H4) |

---

## 3. Findings

### 🔴 HIGH

**H1 — A visitor cannot become a lender. The funnel has no exit.**
There is no registration route in [router.ex](../../lib/kiva_web/router.ex) —
only `GET/POST /login` and `DELETE /logout`. `Accounts.register_user/1` is
called from **seeds and tests only**, never from `lib/`. Every persuasive thing
the site does leads to a door that does not open. The only way in is to adopt a
shared demo persona (`lender@kredo.test`), which is a testing affordance, not an
identity a visitor wants.
*Impact:* the entire visitor journey is unclosable. Everything below is
secondary to this.

**H2 — The chosen borrower is discarded at the wall, twice over.**
Clicking "Support Salma Haddad" pushes to `/login`
([index.ex:70](../../lib/kiva_web/live/loan_live/index.ex#L70)) carrying nothing.
The login page shows no trace of her. Worse, the mechanism that would fix it is
present but dead: `maybe_store_return_to/1` writes `:user_return_to`
([user_auth.ex:70](../../lib/kiva_web/user_auth.ex#L70)) and **nothing ever reads
it** — `log_in_user/2` redirects unconditionally to `signed_in_path(user)`, which
for a lender is `/loans`. So a visitor who chose one specific human out of
3,992 is returned to the undifferentiated list and must find her again.
*Impact:* the strongest moment of intent in the whole product is deliberately
destroyed. This is the highest-value fix after H1 and is nearly free.

**H3 — Two of the three home-page featured loans are not fundraising.**
[page_controller.ex](../../lib/kiva_web/controllers/page_controller.ex) calls
`list_localized_loans(locale, %{})` with **no status filter** and takes 3, under
a heading that reads "Borrowers fundraising now". Verified live: `funded`,
`fundraising`, `repaying`. Two of the three primary calls-to-action on the
landing page lead to a borrower the visitor cannot support, where the CTA is
replaced by "Lending is closed for this loan."
*Impact:* a first click that fails, on the page with the least patience.

**H4 — The conversion page greets a stranger as a returning user.**
`/login` leads with **"Welcome back"** and "Sign in to lend — or try a demo
account below", then lists four personas including `borrower`, `partner`, and
`admin`. A member of the public arriving with intent to give money is asked to
choose whether they are an administrator.
*Impact:* the moment of commitment is where the demo scaffolding is most
visible and most confusing.

### 🟡 MEDIUM

**M1 — The product's most distinctive trust asset is invisible to the actor who
needs it most.** The auditor-grade provenance trail — who photographed the
borrower, who verified identity, who translated the story and how, who approved
it — is gated to staff and admin
([show.ex:747](../../lib/kiva_web/live/loan_live/show.ex#L747)). A visitor's
unspoken question is "how do I know this person is real?", and the product has
an extraordinary answer it does not show them. *Trust & verification*
(endorsements, attestation) **is** public and is a genuine strength; the
provenance trail should join it, in visitor language.

**M2 — Risk is disclosed where the decision isn't made.** The drawer carries the
story and the CTA but not the risk summary or trust model; those are on the full
profile, which the drawer is designed to let you skip. The honest disclosure and
the decision are on different surfaces.

**M3 — No credibility signal on the landing page.** `/loans` opens with
"$1,949,906,075 raised · 1,067,216 active loans · 5 languages". The home page,
whose only job is persuasion, shows none of it.

**M4 — The FAQ answers four questions; a visitor has more.** Present: how lending
works, interest (0%), repayment, partner vs direct. Missing the ones that
actually block a decision: *what if the borrower doesn't repay? can I get my
money back? who is the field partner and why should I trust them? where does my
$25 physically go? what happens to my details?*

**M5 — No social proof at the point of decision.** The profile shows lender
counts, but a visitor sees no faces, no "17 people from 6 countries backed this",
no recent activity. The lending-teams feature — one of the product's most
engaging ideas — is invisible from the browse and decision path.

**M6 — The five-language pillar is invisible unless you go looking.** A visitor
lands in English and must find a globe icon. The product's headline claim is
"in every language" and the home page does not demonstrate it.

### 🟢 LOW

**L1 — The hero leads with "Kredo Demo".** The first badge a visitor reads tells
them not to take it seriously, above the headline. Honesty is right; leading
with it is a choice worth revisiting.

**L2 — Demo-account credentials are published on the public home page**
(a `<details>` table of four logins). Test scaffolding on the marketing surface.

**L3 — No "about", no accountability.** Nothing says who built this, why, or who
to contact — for a site asking for money, the absence is felt.

**L4 — Featured loans link to the full profile, not the drawer.** The home cards
navigate to `/loans/:slug`, bypassing the drawer, which is the better-converting
surface. The best experience is reachable only from the browse page.

### ❓ QUESTIONS (product decisions, not gaps)

1. **Is self-registration in scope for this demo at all?** If persona-switching
   is the intended model, then H1 is not a bug and the honest fix is to say so
   on the landing page ("this is a demo — sign in as any role to explore")
   rather than presenting a conversion funnel that cannot convert. If it is in
   scope, it is the largest single piece of missing product.
2. **Should provenance be public?** It is the most compelling proof the product
   has. It is also the most sensitive (site visits, identity verification).
   Recorded already as `question.provenance.non_admin_visibility`.
3. **Should a visitor be able to build a basket before signing in?** Deferring
   the wall until checkout is the standard e-commerce answer and would make H2
   moot for multi-loan visits.

---

## 4. Story debt summary

1. A journey with no terminal state: the actor cannot become what the product
   asks them to become (H1).
2. Intent destroyed at the boundary, with the repair mechanism already written
   and unused (H2).
3. The landing page's primary CTAs lead to unsupportable loans (H3).
4. The commitment surface speaks to returning users and operators, not to the
   actor standing in front of it (H4).
5. Persuasion assets held back from the actor who needs persuading: provenance,
   scale, social proof, multilinguality (M1, M3, M5, M6).
6. Risk disclosed on a different surface from the decision (M2).

---

## 5. What would make this compelling

Ordered by value per unit of work, not by severity.

**1. Return the visitor to the person they chose.** Store the loan slug on the
way to `/login`, read `:user_return_to` in `log_in_user/2` (the write already
exists), and carry Salma's name and photo onto the login page: *"You're about to
support Salma Haddad — sign in to finish."* This converts the wall into a
doorway and is a handful of lines.

**2. Give the visitor a way in.** Whatever H1's answer, the landing page must
tell the truth about it. Either a real "Create an account" path, or an explicit
demo framing that stops pretending to be a funnel.

**3. Filter the featured loans to fundraising, and pick them well.** Nearly
funded ("$75 to go — you could finish this"), close to expiry, or geographically
varied. The first click should be the best one available.

**4. Move the persuasion to the front.** Scale on the home page; risk and trust
model inside the drawer where the decision happens; a public, human-readable
version of the provenance trail on the profile ("photographed on site 12 March ·
identity verified by the field partner · story translated by a human reviewer").
That last one is the product's unfair advantage and it is currently invisible.

**5. Make the $25 concrete.** "$425 to go" is good. "Your $25 buys the cloth for
eight uniforms" is better. The generator already produces `loan_use` text; the
missing move is arithmetic on the increment, not new content.

**6. Show the language pillar instead of claiming it.** Detect `Accept-Language`
and open in it, or show the same borrower card cycling through five languages on
the home page. The claim is the headline; the demonstration is one component.

**7. Let them commit before they authenticate.** A basket that survives the login
boundary — choose two borrowers, sign in once, fund both — is the standard
pattern and removes the wall from the middle of the emotional peak.

---

## 6. What is already working (do not regress)

- **The browse drawer.** Photo, name, remaining amount, "how this money helps",
  and one personal CTA. It is the best-converting surface in the product.
- **"$425 to go"** — remaining rather than raised, which is the framing that
  creates agency.
- **The three-step explainer** — accurate, honest about relending, no jargon.
- **Public trust & verification** — endorsements and attestation visible without
  an account.
- **Honest 0% disclosure** in the FAQ, and no yield language anywhere.
