# Kredo

**An experiment: how much working product can a handful of AI-assisted sessions
actually produce?**

This repository is the answer to that question, not a product. The interesting
constraint was never capability — given unlimited time you could build anything.
It was **time**: what does a genuinely non-trivial domain look like after only a
few sittings? Multiple actors who need different things, money that has to add
up, content that has to exist in five languages, and a public API with a
real-world contract to match. The whole lending lifecycle is here and it runs end
to end on a laptop.

**It took about 8.6 hours.**

| | |
|---|---|
| Building everything below | **~8.6 h** at the keyboard, in four sittings between 27 Jun and 28 Jul |
| Rebranding, publishing, and auditing it (see `docs/storytime/`) | ~7.2 h across three more days |
| Total | **~15.8 h** |

<sub>Measured from Claude Code session transcripts: time between consecutive
messages, counting only gaps under 30 minutes as active, with overlapping
parallel sessions merged so nothing is double-counted. It undercounts thinking
done away from the keyboard and overcounts nothing.</sub>

> **Unofficial and unaffiliated.** Kredo is an independent experiment inspired by
> the Kiva model. It is **not affiliated with, endorsed by, or connected to Kiva**
> (Kiva Microfunds). It ships a compatibility layer that emulates Kiva's
> *published public API* so existing third-party clients can be pointed at it —
> see [API compatibility](#api-surfaces) below.

> **Demo data only.** No real money and no real people. Every borrower name,
> story, portrait, and translation is synthetic (AI-generated); repayments are
> simulated; passwords are deliberately weak.

---

## What it actually does

The complete loan lifecycle, with a different logged-in experience per actor:

1. **A field partner enrolls a borrower** and drafts a loan application in a
   chat-assisted workspace — reusing facts from that borrower's prior loans
   rather than retyping them — then submits it for review.
2. **Staff review the listing** in a queue: approve and publish it, or send it
   back with a reason. Translations into the other four languages enter their own
   review queue with a `draft → machine → needs_review → approved` lifecycle.
3. **The loan goes live** and lenders browse, filter, and fund it in $25
   increments — alone, through a basket, or on behalf of a **lending team**.
4. **The borrower is repaid, and repays.** The partner records repayments;
   lenders watch money come back on a cumulative repayment chart and relend it.
5. **Everyone gets told what changed.** Cross-actor state changes route through a
   notification layer, so funding, disbursal, and repayment reach the people they
   affect — in their own language.

Alongside that:

- **Five languages, as infrastructure rather than a translation pass.** Every
  content entity has a localized sidecar row; reads go through a resolver with an
  honest fallback badge when a translation is missing. English, Spanish, German,
  French, Dutch.
- **Lending teams** with their own message boards, on-demand post translation,
  and lend-on-behalf-of-the-team attribution.
- **One mutation path.** Every state change — button, form, or chat — goes
  through a single audited command registry: role check → required inputs →
  eligibility → deterministic handler → audit event. The AI assistant cannot
  mutate anything directly; it previews a command and waits for confirmation.
- **A trust layer**: trustees, endorsements, alternative underwriting checks, and
  a hash-chained provenance trail per listing (who photographed it, who
  translated it and how, who approved it).
- **A developer portal** with self-service API keys, OAuth apps, and docs for all
  API surfaces.

## API surfaces

Four of them, because the point was to prove parity with a real-world contract
and *then* design something better:

| Surface | Path | Notes |
|---|---|---|
| **Legacy REST v1** (compat) | `/v1/*.json` | Mirrors Kiva's published `api.kivaws.org/v1` — loan search, detail, lenders, journal entries, partners, teams, `my/*` |
| **Modern GraphQL** (compat) | `/graphql` | Mirrors Kiva's published `api.kiva.org/graphql` — `lend`, `my`, and shop-shaped queries |
| **OAuth2** (compat) | `/oauth/authorize`, `/oauth/token` | So legacy clients can authenticate unchanged |
| **Platform v2** (bespoke) | `/api/v2`, `/api/graphql` | A clean redesign of the same domain, API-key authenticated |

The compatibility layer exists so a client written against the real Kiva API can
be pointed at this server and keep working; it was developed against **KivaLens**
as the reference third-party consumer. It even serves deterministic placeholder
borrower images at Kiva's CDN URL shape, so the whole stack runs offline with no
external calls. Details: [`docs/kiva_api_compatibility.md`](docs/kiva_api_compatibility.md).

## Performance at scale

The generator (below) exists to stress this thing well past demo size. Measured
on one developer laptop — a production build, Postgres on the same machine,
**1,100,205 loans / 5,501,015 localized rows / 1,375,081 lendings**:

| Endpoint | Median |
|---|---|
| `GET /v1/loans/search.json?per_page=100` (incl. exact total over 1.1M) | **78 ms** |
| — the same page without the exact-count requirement | **~5 ms** |
| `GET /v1/loans/{id}.json` (single loan detail) | **2.6 ms** |
| `GET /api/v2/loans` (v2 list) | **3.0 ms** |

Two honest notes on that table, because they are the interesting part:

- The legacy endpoint's 78 ms is almost entirely **one exact `COUNT`** over 1.1M
  rows (~68 ms), which the Kiva API contract requires in every paged response.
  The page fetch underneath it is a few milliseconds. Caching or estimating that
  total is the obvious next optimization and has not been done.
- These numbers are only this good because of indexing work done while measuring
  them: the default newest-first sort was sequential-scanning all 1.1M rows
  (313 ms → 78 ms with one index). Assume other query paths still have
  equivalent traps — the lender dashboard notably does.

---

## Running it

**Requirements:** Elixir 1.19+, PostgreSQL, Node 24+ (for asset builds).

```bash
mix setup
```

That fetches dependencies, creates and migrates the database, seeds a complete
demo world, and builds assets. Then:

```bash
mix phx.server
```

and open <http://localhost:4100>.

By default the app connects to Postgres over the local `/tmp` unix socket as
`$USER`. For TCP instead (containers, CI, a managed database), set `PGHOST` —
`PGPORT`, `PGUSER`, and `PGPASSWORD` are honored too:

```bash
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres mix setup
```

Run the test suite:

```bash
mix test
```

### Sign in

`mix setup` seeds four accounts, one per actor. Every password is `password`.

| Role | Email | Lands on |
|---|---|---|
| Borrower | `borrower@kredo.test` | `/portal` — her loans in her own language |
| Lender | `lender@kredo.test` | `/portfolio` — impact and repayments |
| Partner | `partner@kredo.test` | `/partner` — borrowers, applications, collections |
| Admin | `admin@kredo.test` | `/admin` — review queues, moderation, audit |

Switch languages with the globe menu in the header.

### Generating fake data at any scale

The seeds give you a hand-built world of 200 rich loans with full five-language
content. **No bulk data files are committed to this repository** — scale is
fabricated on demand by a deterministic generator and bulk-loaded with `psql`:

```bash
# 250k loans + 50k lenders, with schedules, lendings, updates, notifications
python3 scripts/loan_gen/build_csv.py --loans 250000 --users 50000
scripts/loan_gen/load.sh
```

Add a deep historical archive on top (lean: loans and localized text only):

```bash
python3 scripts/loan_gen/build_1m.py --count 1000000
scripts/loan_gen/load_1m.sh
```

Run these **after** `mix setup` — they read id maxima and slug→id maps from the
live database so repeated runs never collide. Generation is fully offline: text
comes from a committed pool of 208 five-language templates, so no API key is
needed. Output CSVs land in `scripts/loan_gen/csv/` and are gitignored (a 1M-loan
run weighs about 2.6 GB). `KREDO_DB` overrides the target database.

The full pipeline — including optional OpenAI-powered tooling for regenerating
listing copy and borrower portraits — is documented in
[`scripts/loan_gen/README.md`](scripts/loan_gen/README.md).

### Optional: the AI assistant

A page-aware, role-aware chat assistant is wired into the app. **Ask Mode**
answers questions by running role-scoped GraphQL; **Command Mode** previews a
registered command and executes it only after the actor confirms. With no model
configured it falls back to a deterministic mock, so nothing here requires an API
key. To connect a real model, point it at any OpenAI-compatible endpoint:

| Variable | Meaning | Default |
|---|---|---|
| `KIVA_LLM_ENDPOINT` | Chat-completions URL | `http://127.0.0.1:1234/v1/chat/completions` |
| `OPENAI_MODEL` | Model id | `gpt-5.5` |
| `LLM_API_TOKEN` | Bearer token for that endpoint | `changeme` |

---

## ⚠️ What this is not

**This is an experiment, not a working lending platform, and it would need real
work before it could function as one.** Known gaps, honestly:

- **No real money.** Lending, repayment, disbursal, and currency are all
  simulated. There is no payment processor, no ledger, no reconciliation, and no
  accounting of currency-exchange loss.
- **The AI, translator, moderator, and blockchain attestations are mocks** behind
  clean interfaces. The machine translator is a glossary substitution, not a
  translation engine.
- **The logged-in dashboards need a redesign.** An audit of all four
  ([`docs/storytime/`](docs/storytime/)) found that three of them answer none of
  the questions their actor actually arrives with, one registered command has no
  surface at all, and the chat launcher is currently disabled at the layout level.
- **Performance work is unfinished.** See the notes under the table above; the
  lender dashboard misses its budget at generated scale.
- **Security and abuse handling are demo-grade.** Weak passwords by design,
  demo-grade OAuth token handling, no rate limiting.
- **Not accessibility-audited, not load-tested beyond a single machine, and not
  deployed anywhere.**

If you are looking for the actual thing this imitates, support real borrowers at
[kiva.org](https://www.kiva.org).

---

## How it is built

Elixir / Phoenix / LiveView / Ecto / PostgreSQL / Absinthe GraphQL.

- `lib/kiva/` — domain contexts: `accounts`, `localization`, `content`,
  `taxonomy`, `partners`, `borrowers`, `lending`, `loan_applications`, `teams`,
  `portfolio`, `messaging`, `moderation`, `trust`, `permissions`, `commands`,
  `ai`, `translation`, `provenance`, `audit`.
- `lib/kiva_web/` — LiveViews, the chat component, the Absinthe schema and
  authorization middleware, the Kiva-compatibility controllers (`kiva_v1/`,
  `kiva_graphql/`), and the app shell.
- `priv/repo/` — migrations, seeds, and the JSON content the demo world is built
  from.
- `scripts/loan_gen/` — the scale generator.
- `docs/` — see below.

The project was built documentation-first. `docs/fractalflow/` holds living
system contracts kept in sync with the code, `docs/prd/` is the original planning
corpus, and [`IMPLEMENTATION_LOG.md`](IMPLEMENTATION_LOG.md) is the build log.
Those planning documents predate a late rename and still use the original
working title.

### → [`docs/storytime/`](docs/storytime/) — the actor-journey audits

Probably the most interesting thing in this repository. After the build, Kredo
was audited **as a set of human journeys** rather than as a set of features —
one report per role, a synthesis, and a full enumeration of every lender type.

Those audits found **18 high-severity gaps** in a codebase with **309 passing
tests**, a clean `--warnings-as-errors` compile, and a prior performance pass
behind it: eight mechanisms that were declared and never implemented, a
notification layer that spoke in inverse proportion to what each person had at
stake, and an unmodelled ending for every one of the five actors.

[`docs/storytime/README.md`](docs/storytime/README.md) explains the method and
defines its vocabulary for readers new to LSSD; the
[synthesis](docs/storytime/SYNTHESIS_five_actor_audit_2026-08-12.md) is the
place to start.

> The internal module namespace is still `Kiva.*` / `KivaWeb.*`. Renaming it
> would churn every file for no behavioral gain, and the compatibility layer
> genuinely does model Kiva's API. The product surface is Kredo.

## License

[PolyForm Noncommercial 1.0.0](LICENSE), plus one additional grant:

- **Anyone** may read, run, modify, and share this for any **noncommercial**
  purpose — study, hobby projects, and use by nonprofits, schools, and research
  or government institutions. Running it on your own laptop, which is what the
  setup instructions above are for, is squarely within that.
- **No commercial use** is licensed to any individual, company, or organization,
  with a single exception —
- **Kiva Microfunds** may use it commercially, perpetually, for free.

### If you're from Kiva

This was built as an experiment, not a pitch, and there is no relationship
between it and you. But if any of it is useful — the compatibility layer, the
localization model, the generator, or the whole thing — it's yours. The license
already grants you full commercial rights automatically, with nothing to sign.
If you'd rather own it outright than hold a license to it, I'll assign the
copyright and hand over the repository at no charge; open an issue or get in
touch.

All demo content (stories, translations, portraits) is AI-generated and depicts
no real person.
