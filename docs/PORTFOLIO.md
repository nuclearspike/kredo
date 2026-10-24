# Kredo: AI-assisted platform prototype

**Role:** product direction and engineering oversight — Paul Ericksen / HAU.
**Implementation:** generated with AI assistance, with human decisions, testing
and explicit review of known gaps.
**Stack:** Elixir, Phoenix LiveView, PostgreSQL, Ecto, REST and GraphQL.

I directed Kredo as an independent experiment in building a substantial
multilingual application with AI. It models a lending network with different
workspaces for borrowers, lenders, partners and staff, five-language content,
a Kiva-compatible API layer and auditable commands.

The engineering challenge is keeping one domain coherent across roles,
languages and interfaces. The implementation includes shared command permission
checks, translated content records, simulated loan and repayment workflows,
and a deterministic data generator for larger local datasets.

A separate actor-journey audit records where a passing test suite still leaves
an incomplete user experience. That distinction is part of the case study:
show the working implementation, keep the evidence, and identify what still
needs work before making a production claim.

**See the [three-minute demo](DEMO.md)** and [verification record](RELEASE-READINESS.md).
The ordinary seeded demo runs locally without a hosted model. An optional real
model can power assistant answers; offline scripted mode is explicitly labeled.

All people and financial activity are simulated. Kredo is unfinished, is not
a financial service, and is unaffiliated with Kiva. It is separate from
[KivaLens](https://www.kivalens.org/), the lending-discovery product I built and
maintain. Kredo's existing [PolyForm Noncommercial license and additional grant](../LICENSE)
remain unchanged; describe this repository as source-available, not as
unrestricted commercial open source.

## Freelancer case study copy

**Title:** Kredo: AI-Assisted Platform Demo

**Description:**

I directed and built Kredo with AI assistance as an independent engineering
experiment: a multilingual lending-platform prototype with borrower, lender,
partner and staff workflows. My role was product direction, engineering
decisions and review; AI produced the implementation.

The project combines Elixir/Phoenix LiveView, PostgreSQL, REST and GraphQL,
five-language content, shared command permission checks and audit records.
It includes a Kiva-compatible API surface and a deterministic generator for
local scale experiments. The accompanying walkthrough shows discovery,
role-specific experiences and the developer interface.

The October 23, 2026 check passed 320 tests. Published actor-journey audits also
record unfinished flows, so the evidence includes limitations as well as
working screens. Historical laptop benchmarks are not production guarantees.

All people, loans and financial activity are simulated. Kredo is unfinished,
not a live financial service, and unaffiliated with Kiva. Its assistant has an
offline scripted mode and an optional real-model backend. This case study
shows how I direct AI-assisted development while keeping behavior and claims
reviewable.

**Suggested tags:** Elixir, Phoenix, PostgreSQL, API integration, GraphQL,
localization, automated testing.

**Publication boundary:** Paul approved the source release and this portfolio
entry on October 23, 2026. Verify the public source and demo links signed out
before publishing the entry. Internet deployment of the application is a
separate decision.
