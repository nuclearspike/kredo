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

**Nodes are typed.** A line beginning `truth`, `command`, `policy`, `actor`,
`outcome`, `story`, `stage`, `reveal`, `view`, `capability`, `question`,
`decision_record`, `finding`, or `evidence` opens a record of that kind. The type
tells you what obligations it carries — a `command` must name who may run it and
what must be true first; a `reveal` must name who is told and through what.

**Every claim carries an evidence label.** Across these ten files:

| Label | Count | Means |
|---|---|---|
| `observed` | 291 | verified in the code as it exists |
| `asserted` | 82 | declared or ruled, **not built yet** |
| other | ~30 | `confirmed`, `committed`, `unknown` on specific record types |

An `asserted` node is a promise, not a description. Several audit findings in
`../storytime/` are exactly the gap between the two labels.

**Each file declares the code it governs.** The header carries `Canonical-For:`
with the paths it is the authority for, and `Status: ACTIVE`.

---

## The contracts

| Contract | Nodes | Governs | What it models |
|---|---|---|---|
| [`kiva_future_demo_product.lssd.md`](kiva_future_demo_product.lssd.md) | 54 | *(root)* | **Start here.** The product model: capabilities, product-level outcomes, the initiative ledger of committed work, and the decision records behind the big rulings (rebrand, licence, the 0%-interest invariant, bulk collections, the risk-details page) |
| [`loan_lifecycle_subsystem.lssd.md`](loan_lifecycle_subsystem.lssd.md) | 98 | `lending`, `loan_applications`, `portfolio`, the lender/partner LiveViews | The largest contract. Loan states, the repayment loop, lender and partner journeys with first-person stage records, the search and publishing policies, and the finding that lenders earn 0% |
| [`messaging_reveal_subsystem.lssd.md`](messaging_reveal_subsystem.lssd.md) | 56 | `messaging`, `moderation`, `notifications` | Cross-language encouragement, the moderation pipeline, the borrower's portal journey, and the reveal layer — who gets told what, and where silence was never decided |
| [`permissions_trust_subsystem.lssd.md`](permissions_trust_subsystem.lssd.md) | 39 | `permissions`, `trust`, `audit` | Permission groups and direct grants, the outlier dashboard, trustees, endorsements, and blockchain attestations |
| [`lending_teams_subsystem.lssd.md`](lending_teams_subsystem.lssd.md) | 32 | `teams`, `basket`, team LiveViews | Lending teams, lend-on-behalf, the basket, and team message boards |
| [`ai_dialogue_subsystem.lssd.md`](ai_dialogue_subsystem.lssd.md) | 31 | `ai`, `chat_live`, the GraphQL surface | The assistant: Ask Mode over role-scoped reads, Command Mode's preview→confirm discipline, the command registry as one capability kernel, and the audit of eligibility gates that never ran |
| [`localization_subsystem.lssd.md`](localization_subsystem.lssd.md) | 31 | `localization`, `translation` | Five-language content as infrastructure: sidecar rows, the fallback resolver, the translation review lifecycle, and the locale-precedence bug that defeats it at login |
| [`provenance_subsystem.lssd.md`](provenance_subsystem.lssd.md) | 20 | `provenance` | The auditor-grade authenticity trail per listing — who photographed, verified, translated, and approved, hash-chained |
| [`identity_access_subsystem.lssd.md`](identity_access_subsystem.lssd.md) | 11 | `accounts`, plugs, session controller | Sign-in, roles, session and locale resolution |
| [`developer_compat_subsystem.lssd.md`](developer_compat_subsystem.lssd.md) | 10 | `kiva_v1`, `kiva_graphql`, developer portal | **Skeleton.** The API-compatibility surfaces and developer portal. Deliberately shallow — authored to resolve an open question, with its depth left as a recorded question rather than invented |

---

## Where the interesting parts are

If you are browsing rather than working:

- **The rulings** — `decision_record` nodes in the product contract capture why
  things are the way they are, including decisions that reversed earlier work.
- **The open questions** — `question` nodes are unanswered product decisions,
  written down instead of guessed. There are 15+ across these files, and several
  block real work.
- **The findings** — `finding` and `evidence` nodes record what went wrong and
  how it was proven, including two claims that were raised and then **withdrawn
  against data** rather than quietly deleted.
- **`asserted` truths with no code** — `user.profile_public`,
  `loan.loss_attribution`, `repayment.arrears_aging` exist here and nowhere else.
  They were created by writing what an actor's moment should feel like and
  discovering the schema could not support it.
