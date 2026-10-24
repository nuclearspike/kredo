# Kredo in three minutes

An AI-assisted engineering prototype directed by Paul Ericksen. **Every person,
loan and payment shown is simulated.** Kredo is independent of Kiva and separate
from the KivaLens product. This is a guided demo of a local application, not a
live lending service.

## 1. Discover a loan (about one minute)

![Kredo's loan discovery interface with synthetic borrowers](screenshots/01-browse-loans.webp)

Start on **Loans**. Compare stories, countries, sectors and funding progress,
then open a listing. The loan-detail page brings translated content, repayment
information and a lending action into one view. This demonstrates domain
modeling and a data-driven interface; it does not promise repayment or process
real funds.

[Inspect a sample loan screen](screenshots/04-loan-detail-construction-materials.webp).

## 2. Change perspective and language (about one minute)

![Synthetic borrower's portal in German](screenshots/17-borrower-portal-de.webp)

The same application presents different work to borrowers, lenders, partners
and staff. A borrower sees their loans and incoming messages; a lender sees
portfolio activity. English, German, Spanish, French and Dutch are included.
Use the language menu to change the interface; the demo content is generated,
and translations have not been certified by native speakers.

[Compare the lender's My impact screen](screenshots/09-lender-my-impact.webp).

## 3. Inspect the engineering (about one minute)

![Developer explorer querying the synthetic lender's loans](screenshots/24-developer-graphiql-lendings.webp)

Developers can inspect REST and GraphQL interfaces. Registered commands share
permission checks and audit recording; the assistant's command flow uses
preview and confirmation. The optional model backend is separate from that
command boundary. With no model configured, the assistant labels its scripted
offline mode.

Look at [`Kiva.Commands`](../lib/kiva/commands.ex),
[API compatibility tests](../test/kiva_web/kiva_v1/rest_test.exs) and the
[actor-journey audit](storytime/SYNTHESIS_five_actor_audit_2026-08-12.md).
The October 23 check passed **320 tests**. Tests support specific behavior;
they do not establish production readiness.

## Run the local walkthrough

Follow [the README setup](../README.md#running-it), then visit
`http://127.0.0.1:4100`. Keep the development service on localhost.

- Start signed out: **Loans → a loan**.
- Choose **Sign in**. Use `borrower@kredo.test`, `lender@kredo.test`,
  `partner@kredo.test` or `admin@kredo.test`, all with the public demo password
  `password`. Switch roles by signing out first.
- Use **Developers** for API documentation and the explorer. No real lender
  account, payment method or hosted AI subscription is needed for the basic demo.

The seeded database is a demonstration world. Do not enter client data,
real financial information or reusable credentials. Do not run `mix ecto.reset`
on an existing database to recover a failed demo: it drops data. Keep an existing
installation intact and use a separate local checkout/database for experiments.
If setup is unavailable, this walkthrough and the [24-screen gallery](screenshots/README.md)
remain usable without signing in.

## Evidence and limits

The gallery screenshots above were captured August 12, 2026 from generated demo
data. They are labeled historical examples, not proof of a newly deployed
service. Fresh October checks and unresolved limits are listed in
[Release readiness](RELEASE-READINESS.md). Lending, settlement, translation,
moderation and attestations have the limitations described in the README.

[Back to the project](../README.md) · [Portfolio case study](PORTFOLIO.md)
