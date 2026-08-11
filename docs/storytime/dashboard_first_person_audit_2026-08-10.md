# StoryTime Audit — Logged-in Dashboards, First-Person Layer (v1.12)

**Date:** 2026-08-10 · **Scope:** `/portal` (borrower), `/portfolio` (lender),
`/partner` + `/partner/repayments` (partner), `/admin` (staff/admin)
**Method:** code read of all five LiveViews + rendered cold-reads of each surface
logged in as the demo actor (screenshots, 1280×2500), against StoryTime Laws
1–19 with emphasis on the v1.12 first-person layer (Laws 22–24: monologue +
ranked question stacks, transcribed strings, answer-before-offer, folded-region
signal) and `~/.claude/PAUL-UX-RULES.md`.
**Verdict in one line:** the lender page already lives in the new world; the
other three render machine lifecycles at equal weight and answer almost none of
their actor's opening questions — and two cross-cutting regressions (chat dark,
locale precedence) undercut the product's two stated pillars.

---

## 1. Actor story map

| Actor | Surface | Focused artifacts | Stage audited |
|---|---|---|---|
| Rosa — borrower (es) | /portal | her loans, schedule, encouragement | "logged in, one loan fundraising, seven repaid" |
| Morgan — lender (en) | /portfolio | 1,408 lendings, repayments | "returning lender, money available to relend" |
| Ana — partner (es) | /partner, /partner/repayments | 77K loans, drafts, repayments due | "morning operational check-in" |
| Jordan — staff/admin | /admin | queues, audit, analytics | "what needs my decision today" |

---

## 2. First-person layer — derived question stacks (the storyboard seeds)

None of the four stages has a monologue, question stack, lexicon, or screenplay
(v1.12 constructs; pre-v1.12 surfaces are legacy-compliant until touched — and
this audit is the touch). Derived here; these become the contract entries when
each dashboard is reworked.

### Rosa — borrower opening /portal
> *"¿Ya llegó el dinero? ¿Cuánto pago y cuándo? ¿Alguien dijo algo de mí?"*

1. **Is my money coming — how close is my loan?** → answering truth: funded % / amount remaining (exists per-card, never headlined)
2. **What do I owe next, and when?** → next scheduled item (exists, buried mid-card)
3. **Did anyone encourage me / who?** → messages (shown, but unattributed)
4. **What should I do now?** → `post_borrower_update` (command exists; **no surface**)

**Current headline:** "My portal" + welcome line — answers nothing (Law 23 miss).
**Transcription target (es-source):** "Tu préstamo está al 76% — faltan $225.
Tu próximo pago: 28 dic · $118.75."

### Morgan — lender opening /portfolio
1. **What has my money done?** → ✓ hero: total lent / repaid ring / borrowers / countries
2. **Is any of it in trouble?** → ⚠ behind-schedule badge only; **losses summed nowhere**
3. **What can I do now?** → ✓ relend banner (the page's one action — correct)
4. **Find a specific loan/borrower** → facets ✓, **no text search** across 1,408

This page is the house exemplar of Law 23 — keep it; close the risk gap.

### Ana — partner opening /partner
> *"¿Qué cobro hoy? ¿Qué me devolvió el equipo de revisión? ¿Qué campaña está por vencer?"*

1. **What must I collect today (count + $)?** → stat #4 + "Manage" link only
2. **What came back from staff review?** → `changes_requested` drafts — buried, undifferentiated, labeled by raw id
3. **What's about to expire underfunded?** → truth exists (`fundraising_ends_at`); **no surface**
4. **Start/continue applications** → the grid — currently the *primary* surface

The workspace is inverted: the application factory (lifecycle) leads; the
operational morning (journey) trails or is absent.

### Jordan — staff opening /admin
1. **What awaits my decision, how much, how old?** → queues render *below* analytics; counts ✓, aging absent
2. **Anything anomalous?** → outliers/denied-AI exist further down; no signal in headers
3. **System pulse** → currently *leads* the page as raw tables

**Transcription target:** "9 decisions waiting — 0 loans · 105 translations
(oldest 3 d) · 2 held messages · 1 permission outlier."

---

## 3. Findings

### 🔴 HIGH

**H1 — The chat-first product has no chat.**
`live_render(KivaWeb.ChatLive)` is commented out ("hidden for now") in
`lib/kiva_web/components/layouts/root.html.heex:41-43`; all four dashboards
pass `live_chat={true}` into a layout that never renders it. Ask Mode, Command
Mode, preview→confirm — the product's signature architecture — is unreachable
from every surface (admin's "AI tool calls: 11" are historical). Agent-parity
story: dark.

**H2 — The native-language promise breaks at first login.**
`lib/kiva_web/plugs/set_locale.ex:14-24`: precedence `params > session > user
default`, and the resolved value is written back to session on *every* request
— so an anonymous visit's "en" fallback becomes a sticky session choice that
permanently shadows the borrower's `default_locale_code`. Observed: Rosa
(default es) gets an English portal titled "Here are your loans in your
language." Fix shape: persist session locale only on *explicit* choice
(`LocaleController`), and/or seed session locale from the user at login.

**H3 — Partner drafts wall speaks implementer, not actor (A44).**
`lib/kiva_web/live/partner_live.ex:318-347`: rows render `#3000003 · draft ·
Continue` — raw internal id, no borrower name, no title, no date, no amount;
unpaginated; `changes_requested` (staff bounced it — the urgent one) is mixed
undifferentiated into the pile. `recognized_by` rendering (name/photo/when)
absent entirely.

**H4 — Translation review offers a decision it doesn't equip.**
`lib/kiva_web/live/admin_live.ex:326-360`: 105 flat rows, each Approve/Reject
against a *truncated target-only* snippet — the source text is never shown, nor
confidence, method (machine/template/human), or the owning loan. The reviewer
cannot actually review from the surface that demands the verdict (Law 2 + Law
23 inversion). No grouping by loan/locale, no pagination, no bulk path for
machine-translations-above-threshold.

**H5 — Partner workspace leads with the factory, not the morning.**
`lib/kiva_web/live/partner_live.ex:196-312`: primary real estate = borrower
grid + "New loan" buttons (application creation), while collect-today lives as
stat #4, bounced submissions as H3's wall, and expiring-underfunded campaigns
have **no surface at all** (truth exists: `fundraising_ends_at`). Journey debt,
textbook.

**H6 — Borrower portal answers nothing and offers nothing.**
`lib/kiva_web/live/portal_live.ex`: no headline truth (Law 23); zero available
decisions on the page — notably `post_borrower_update` is a registered command
(`lib/kiva/commands.ex:119`) with **no surface anywhere** (command-coverage
orphan); completed loans render as empty husks (title + badge, no closure —
"repaid $950 over 14 months" moment missing); encouragement messages are
unattributed (no sender, date, or loan) with no acknowledge/thank path (the
lender→borrower reveal edge has no return edge).

### 🟡 MEDIUM

**M1 — Machine-lifecycle leaks into actor surfaces (Law 14).**
`portal_live.ex:23-27`: `next_payment/1` falls back to `List.first(items)` — a
76%-funded *fundraising* loan shows "Next repayment: 2026-12-28 — $118.75."
`portfolio_live.ex:1115-1131`: fundraising rows render "0/18 repayments" +
empty progress bar (renders whenever `total_count > 0`, regardless of status).

**M2 — Lender risk under-reveal.**
No summed "lost to defaults" or delinquent-exposure truth anywhere on
/portfolio; the 66% ring is silent about the $22,396 behind schedule (small
badge) and defaults entirely. "Understand risk honestly" is the stated lender
role; the surface doesn't.

**M3 — No text search on the two biggest lists.**
/portfolio loans (1,408 — facets only, `portfolio_live.ex:920-977`); /partner
borrower grid (thousands, blind Next/Prev, duplicate-looking generated names,
`partner_live.ex:274-312`). "Did I lend to María?" → unanswerable without Ask
Mode (which is dark, H1).

**M4 — Repayments-due rows omit the decision's truths and scale path.**
`lib/kiva_web/live/partner/repayments_live.ex:89-110`: no due date, no amount,
no overdue-aging on rows; "Record repayment" doesn't say what it will record;
1,992 due × single-click ceremony across 80 pages — no bulk "record today's
collections" flow.

**M5 — Admin page is machine-first and number-raw.**
`admin_live.ex:167-225`: analytics tables lead the page; queues follow.
Unformatted counts (`1035121` — `num/2` exists and is unused here); the
translation-coverage card shows the identical total for all five locales
(vacuous stat); the 105-row queue is unpaginated (`Translation.list_review_queue/0`
is unbounded).

**M6 — Flash toast overlaps the header nav** (covers Teams/Help/bell on every
dashboard) — collision, borderline Rule-2 class.

### 🟢 LOW

- **L1** `admin_live.ex` AI-calls table: fixed recent-25, no filter/drill; fine for demo, note for growth.
- **L2** Repaid ring mixes cohorts (repaid ÷ total-including-active). The honest pair (received ÷ scheduled-to-date) already exists in the chart.
- **L3** Portal fallback badge prints a locale code ("EN") — machine detail where actor phrasing belongs ("shown in English — Spanish translation pending review").
- **L4** Partner stat "Active loans: 77,552" is actually *all* loans (completed included) — truth-label mismatch.

### ❓ QUESTIONS — ANSWERED by Paul, 2026-08-10

- **Q1 → Public-profile-gated reveal.** Sender identity (and the thank/reply
  path) crosses to the borrower **only when the sender's profile is public**;
  otherwise the message stays anonymous. Forces a new truth:
  `user.profile_public` (lender-controlled visibility flag) — does not exist in
  the schema yet. → `decision.encouragement_sender_reveal`.
- **Q2 → Bulk collections.** Partner repayment recording becomes a day-batch
  flow ("record today's collections" with preview→confirm through the command
  registry), replacing 1,992 single-click ceremonies.
  → `decision.partner_bulk_collections`.
- **Q3 → Dedicated risk-details page.** The portfolio hero stays warm; a
  separate details surface breaks down currency/exchange loss, defaults, and
  amounts in arrears, sliced by country and partner. Forces new derived truths
  (per-loan loss attribution, arrears aging). → `decision.lender_risk_details_page`.
- **Q4 → Regression, fix it.** The commented-out launcher was never a product
  decision; restore the chat (H1). → `decision.restore_chat_launcher`.

---

## 4. Story-debt summary (punchlist)

1. Chat dark everywhere — flagship architecture unreachable (H1).
2. Locale precedence defeats the localization pillar at login (H2).
3. Three of four dashboards fail answer-before-offer; only /portfolio passes (H3–H6).
4. Registered command with no surface: `post_borrower_update` (H6).
5. Truth that exists but never surfaces: expiring-underfunded campaigns; summed default losses (H5, M2).
6. Decisions offered without their evidence: translation Approve/Reject sans source (H4); Record repayment sans amount/date (M4).
7. Lifecycle-as-journey leaks: repayment lines on fundraising loans (M1); raw ids as labels (H3); analytics before queues (M5).
8. No fold discipline: 105-row and 22+-row walls with naked headers — L84 (count/worst/delta) applied nowhere.

---

## 5. Rethink directions (per dashboard, concrete)

**Portal → "Rosa's money page."** Answer-first hero from her top question
(state-dependent: fundraising → % + remaining + days left; repaying → next
due + amount + on-track); action row (post update · see supporters · ask);
messages with sender/date/loan + thank-acknowledge (pending Q1); completed
loans folded per L84 with a closure line ("Repaid $950 over 14 months ✓");
rendered in `es` (H2 fix is a prerequisite for every borrower string).

**Portfolio → keep the hero, add honesty + findability.** One risk line under
the ring ("$22.4k behind · $N lost across M loans → filter"); borrower/loan
text search beside the facet selects; suppress repayment scaffolding on
fundraising rows (show "fundraising — X% · ends in N days" instead).

**Partner → invert to "Today."** Lead block: collect-today (count + $ + bulk
entry into a day-batch flow, Q2), bounced submissions (actor-labeled, pinned),
expiring-underfunded campaigns (new surface for existing truth); borrower
search; drafts re-labeled in actor voice ("María — sewing machine · $500 ·
started Tue · missing photo"), `changes_requested` first, paginated; the
application factory grid moves second.

**Admin → queues first, evidence in the row.** Header strip = transcription
target above (counts + oldest-age per queue, L84); translation review becomes
source⇄target pairs with method/confidence + per-loan grouping + bulk
approve-machine-above-threshold (preview→confirm through the registry);
analytics collapse to the bottom (formatted via `num/2`, drop the vacuous
coverage card); toast placement fix (M6).

**Cross-cutting order of operations.** (1) H1 + H2 are prerequisites — every
redesigned string is transcribed per-locale and half the affordances route
through chat parity. (2) Then per-dashboard reworks, each preceded by its
screenplay + question stack landing in the owning contract (this doc seeds
them). (3) Pattern extractions once two surfaces share the shape:
`answer-first-hero`, `folded-region-header`, `evidence-bearing-queue-row` —
candidates for `PATTERNS_AND_ADOPTIONS` binding, not yet debt.

---

## 6. Enforcement notes (Law 16)

Mechanically checkable candidates once reworks land: headline-answers-stack
(each dashboard's hero renders the stage's top answering truth — assert on
element ids); no-repayment-scaffold-on-fundraising (M1 regression test);
locale-at-login (H2 test: login as es-default user from en session → es page);
chat-mounted (H1 test: FAB present on every `live_chat` page).

*Screenshots from this audit session: borrower portal, lender portfolio,
partner workspace, repayments due, admin ops — captured 2026-08-10 against the
post-rebrand build with generated-scale data (77K partner loans, 1,408-loan
lender).*
