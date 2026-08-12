# Kredo, in screenshots

Twenty-four screens captured on 12 August 2026, on one developer laptop, against a
generated dataset of **1,100,205 loans / 5,501,015 localized rows / 1,375,081
lendings**. Every borrower, partner, photograph and figure here is fabricated.
No real money moves.

The sections below are **actors**, not features, because that is how the product
is modelled: a loan is not the story, it is an artifact created by decisions
inside several overlapping stories. See [`../fractalflow/`](../fractalflow/) for
those models and [`../storytime/`](../storytime/) for a deliberately unflattering
account of what is still missing behind these screens.

**Jump to:** [Discover](#discover) · [The lender](#the-lender) ·
[Five languages](#five-languages-all-the-way-down) · [Staff & admin](#staff--admin) ·
[Developers](#developers)

---

## Discover

*Anyone who arrives.* What a visitor sees before they have an account.

### Browse loans
Over a million loans, filtered by status, sector, country and free text. Search
matches the language the reader is actually being shown, not all five at once.

![Browse loans page with a dark green hero, status and sector filter chips, and a grid of borrower cards](01-browse-loans.webp)

### Home
“Loans that change lives — in every language.” Borrowers fundraising now, straight
under the fold.

![Kredo landing page](02-home.webp)

### Help & FAQ
How lending, repayment and the trust models work, in plain language.

![Help and FAQ page](03-help-and-faq.webp)

### A loan page
The borrower’s story, the funding bar, the repayment terms, and who else has lent.

![Loan detail for construction materials](04-loan-detail-construction-materials.webp)

Salma Haddad, Jordan — clothing and tailoring, socially underwritten.

![Loan detail for a school-uniform fabric order](05-loan-detail-school-uniform-fabric.webp)

Equipment finance for a Vietnamese mill.

![Loan detail for a grinder for a mill](06-loan-detail-grinder-mill.webp)

### Lending teams
People lend together and their totals are pooled; each team has its own page and
message board.

![Lending teams index](07-lending-teams.webp)

![Team detail page with funding totals and a message board](08-team-detail.webp)

---

## The lender

*Signed in as a lender.* A lender earns **nothing** — every dollar back is
principal returned. These screens are built around that fact.

### My impact
Total lent, and how much has come back and is ready to lend again.

![My impact page](09-lender-my-impact.webp)

### Money coming back
Cumulative repayments against the schedule — capped at the principal, because the
return is zero by design.

![Chart of cumulative repayments over time](10-lender-money-coming-back.webp)

### Sectors you support
Where the money went, by sector and count.

![Breakdown of sectors supported](11-lender-sectors-supported.webp)

### Loans you’ve touched
Every loan this lender has funded, with status, country, sector and partner
filters — and the same list regrouped by country, where thousands of lendings
across fifteen countries stay legible.

![List of loans the lender has funded](12-lender-loans-touched.webp)

![The same list grouped by country](13-lender-loans-grouped-by-country.webp)

### Repayment schedule
Month by month, what is due and what has been paid.

![Repayment schedule table](14-lender-repayment-schedule.webp)

### Notifications
Funding, disbursal and repayment events, revealed to the people they concern.

![Notifications list](15-lender-notifications.webp)

---

## Five languages, all the way down

Translation is infrastructure here, not a setting. Loan content is stored per
language and resolved for the reader, and a loan cannot go live until every
language has been reviewed. The borrower reads their own page in their own
language.

### The borrower’s portal — English, German, Spanish
“Here are your loans in your language.” The same screen, resolved into each
language as content rows, not a UI string swap.

![Borrower portal in English](16-borrower-portal-en.webp)

![The same borrower portal in German](17-borrower-portal-de.webp)

![The same borrower portal in Spanish](18-borrower-portal-es.webp)

### French and Dutch
Borrower stories and the how-it-works explainer in French; a full loan page in
Dutch, borrower story included.

![French home page](19-home-fr.webp)

![Dutch loan detail page](20-loan-detail-nl.webp)

---

## Staff & admin

*Signed in as staff.* The operational side.

### Staff & admin operations
Loans by status and country, funding by sector, translation coverage per locale —
over the full 1.1M-loan dataset. The time machine at the top steps every active
loan through fund → disburse → repay → complete so the whole demo visibly moves.

![Staff and admin operations page with distribution analytics](21-admin-operations.webp)

### Moderation & permission outliers
Held encouragement messages, and every account holding a permission its role does
not normally carry — here, a lender who can approve loan listings.

![Admin view of moderation and permission outliers](22-admin-moderation-and-outliers.webp)

### Partners & trustees
Field partners by country and trust model, each suspendable, plus community
trustees.

![Partners and trustees table](23-admin-partners-and-trustees.webp)

---

## Developers

*Signed in as a developer.* The same data the interface uses, reachable directly.
Kredo also serves a legacy-compatible REST and GraphQL surface, so an unmodified
third-party Kiva client can run against it.

![GraphiQL explorer running a query for the signed-in lender's loans and their statuses](24-developer-graphiql-lendings.webp)

---

**Kredo is a demo, and unfinished.** The screens here are the parts that work.
The audits in [`../storytime/`](../storytime/) are an honest account of the gaps
behind them.
