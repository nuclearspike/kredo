# FractalFlow Contracts — the living model of what this system *is*

Ten documents that describe Kredo's actors, truths, commands, policies, reveals,
and open questions. They are **kept in sync with the code as a rule of the
project**: when a flow, policy, persisted truth, command, or reveal surface
changes, the nearest contract is updated in the same pass.

They are not documentation *about* the code written after the fact. They are the
semantic authority the code is written against, and the thing an audit projects
from.

> **Part of an AI-run experiment.** Kredo was built, contracted, and audited by
> an AI agent under human direction. These contracts were authored the same way,
> then upgraded to current LSSD grammar in a later pass. Kredo is an unfinished
> demo; the contracts describe it honestly, including the parts that do not work.

**Related:** [`../storytime/`](../storytime/) — actor-journey audits projected
from these contracts, and a glossary of the vocabulary used here ·
[`../prd/`](../prd/) — the original planning corpus these contracts replaced.

---

## How to read one

You do not need the grammar to get value from these files. Three conventions
carry most of the meaning:

**Nodes are typed.** A line beginning `truth`, `command`, `policy`, `obligation`,
`actor`, `outcome`, `story`, `stage`, `view`, `interface`, `capability`,
`question`, `decision_record`, `finding`, or `evidence` opens a record of that
kind. The type tells you what it must carry — a `command` must name who may run
it and what must be true first; a `view` must name who is told and through what;
an `interface` must name an external boundary and what crosses it.

The grammar defines 55 kinds and these contracts use 36 of them. An unused kind
is not automatically a gap — but it is worth asking about, and on 2026-08-12
asking found four real ones:

- **`interface`** was unused, so no external boundary had a node. That is what
  let the AI subsystem's contract assert it had no external provider while the
  code was posting conversation history to a chat-completions endpoint
  (`finding.ai.contract_understated_egress`). Four boundaries are now declared:
  the model endpoint, `/v1`, the GraphQL mirror, `/oauth`, and `/api/v2`.
- **`obligation`** was unused, so must-dos lived as prose in `metadata`. Writing
  one for repayment surfaced that a loan disbursed at runtime never got a
  repayment schedule and silently never repaid
  (`finding.repay.runtime_loans_never_repay`, now `retired` — the bug was fixed
  the same day, and the finding is kept rather than deleted because the shape of
  the miss is worth remembering).
- **`provenance_record`** was unused in a subsystem whose entire job is lineage.
- **`evaluation`** was unused although the performance numbers had been measured.

The remaining 19 divide into two groups. Genuinely inapplicable here:
`experiment`, `experiment_trial`, `benchmark`, `reference_set`, `golden_case`,
`evaluation_rubric`, `compatibility_profile`, `deprecation_record`,
`recovery_playbook`, `exception_record`, `recipe_binding`, `contract`, `note`,
`opportunity`. Deliberately **not** filled: `observed_scenario`,
`friction_observation`, `optimization_hypothesis`, and `preset` are the journey‑
optimization layer, and they are only honest when mined from a real record of
people using the thing. Nobody has used Kredo. Authoring them from imagination
is precisely the failure that layer exists to prevent, so they stay empty and
said so. `realization` is unused because the `Canonical-For` header does that
job at file grain.

**Every claim carries an evidence label.** Across these ten files:

| Label | Count | Means |
|---|---|---|
| `observed` | 313 | verified in the code as it exists |
| `asserted` | 83 | declared or ruled, **not built yet** |
| other | 28 | `confirmed`, `committed`, `unknown`, `retired`, `delivered`, `candidate` on specific record types |

An `asserted` node is a promise, not a description. Several audit findings in
`../storytime/` are exactly the gap between the two labels.

**Each file declares the code it governs.** The header carries `Canonical-For:`
with the paths it is the authority for, and `Status: ACTIVE`.

---

## The contracts

Node counts below are top-level declarations in each file's `lssd` blocks,
excluding the `model` version header.

| Contract | Nodes | Governs | What it models |
|---|---|---|---|
| [`kiva_future_demo_product.lssd.md`](kiva_future_demo_product.lssd.md) | 59 | *(root)* | **Start here.** The product model: capabilities, product-level outcomes, the initiative ledger of committed work, and the decision records behind the big rulings (rebrand, licence, the 0%-interest invariant, bulk collections, the risk-details page) |
| [`loan_lifecycle_subsystem.lssd.md`](loan_lifecycle_subsystem.lssd.md) | 112 | `lending`, `loan_applications`, `portfolio`, the lender/partner LiveViews | The largest contract. Loan states, the repayment loop, lender and partner journeys with first-person stage records, the search and publishing policies, and the finding that lenders earn 0% |
| [`messaging_reveal_subsystem.lssd.md`](messaging_reveal_subsystem.lssd.md) | 58 | `messaging`, `moderation`, `notifications` | Cross-language encouragement, the moderation pipeline, the borrower's portal journey, and the reveal layer — who gets told what, and where silence was never decided |
| [`permissions_trust_subsystem.lssd.md`](permissions_trust_subsystem.lssd.md) | 40 | `permissions`, `trust`, `audit` | Permission groups and direct grants, the outlier dashboard, trustees, endorsements, and blockchain attestations |
| [`lending_teams_subsystem.lssd.md`](lending_teams_subsystem.lssd.md) | 33 | `teams`, `basket`, team LiveViews | Lending teams, lend-on-behalf, the basket, and team message boards |
| [`ai_dialogue_subsystem.lssd.md`](ai_dialogue_subsystem.lssd.md) | 47 | `ai`, `chat_live`, the GraphQL surface | The assistant: Ask Mode over role-scoped reads, Command Mode's preview→confirm discipline, the command registry as one capability kernel, the audit of eligibility gates that never ran, and the real-model backend — what it sends, when it degrades to the offline script, and the constraint that nothing leaves the machine unconfigured |
| [`localization_subsystem.lssd.md`](localization_subsystem.lssd.md) | 41 | `localization`, `translation` | Five-language content as infrastructure: sidecar rows, the fallback resolver, the translation review lifecycle, and the locale-precedence bug that defeats it at login |
| [`provenance_subsystem.lssd.md`](provenance_subsystem.lssd.md) | 24 | `provenance` | The auditor-grade authenticity trail per listing — who photographed, verified, translated, and approved, hash-chained — with one `provenance_record` carrying the whole lineage: sources, agents, transformations, custody, integrity, and the limits of what a fabricated history can honestly claim |
| [`identity_access_subsystem.lssd.md`](identity_access_subsystem.lssd.md) | 12 | `accounts`, plugs, session controller | Sign-in, roles, session and locale resolution |
| [`developer_compat_subsystem.lssd.md`](developer_compat_subsystem.lssd.md) | 20 | `kiva_v1`, `kiva_graphql`, developer portal | **Part skeleton.** The four external boundaries — legacy `/v1`, the GraphQL mirror, `/oauth`, and Kredo's own `/api/v2` — plus how a request is attributed to a user and what the surfaces cost at 1.1M loans, all read from the router. The developer's journey across them is still deliberately ungrown, left as a recorded question rather than invented |

---

## Where the interesting parts are

If you are browsing rather than working:

- **The rulings** — `decision_record` nodes in the product contract capture why
  things are the way they are, including decisions that reversed earlier work.
- **The open questions** — `question` nodes are unanswered product decisions,
  written down instead of guessed. There are 12 across these files, and several
  block real work.
- **The findings** — `finding` and `evidence` nodes record what went wrong and
  how it was proven, including two claims that were raised and then **withdrawn
  against data** rather than quietly deleted.
- **`asserted` truths with no code** — `user.profile_public`,
  `loan.loss_attribution`, `repayment.arrears_aging` exist here and nowhere else.
  They were created by writing what an actor's moment should feel like and
  discovering the schema could not support it.
