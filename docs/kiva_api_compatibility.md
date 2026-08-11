# Kiva API Compatibility Layer

This app exposes a **Kiva-compatible API** so a site migrated to this platform can
serve legacy Kiva clients (e.g. the original KivaLens) unchanged. It replicates the
two real Kiva public surfaces, backed by an adapter over our data model:

| Surface | Real Kiva | Mounted here |
|---|---|---|
| Legacy REST v1 | `api.kivaws.org/v1/*.json` | `/v1/*` (the `.json`/`.xml` suffix is honored) |
| Modern GraphQL | `api.kiva.org/graphql` | `/graphql` (+ GraphiQL at `/dev/kiva/graphiql`) |
| OAuth2 | `kiva.org/oauth`, `api.kivaws.org/oauth/token` | `/oauth/authorize`, `/oauth/token` |

Our own bespoke API (`/api/v1`, `/api/graphql`) is unchanged and unaffected. The
compat layer lives entirely under the `KivaWeb.KivaV1`, `KivaWeb.KivaGraphql`, and
`KivaWeb.KivaCompat` namespaces; the shared adapter is
[`KivaWeb.KivaCompat.Mapping`](../lib/kiva_web/kiva_compat/mapping.ex).

## Endpoints

### Legacy REST v1 (`/v1`)

| Endpoint | Notes |
|---|---|
| `GET /v1/loans/search.json` | filters: `status`, `gender`, `sector`, `country_code`, `region`, `partner`, `q`, `sort_by`, `page`/`per_page`, `ids_only` |
| `GET /v1/loans/newest.json` | search, forced newest-first |
| `GET /v1/loans/:ids.json` | batch detail (≤100 comma-separated ids), no `paging` |
| `GET /v1/loans/:id/lenders.json` | who funded the loan (anonymous lendings omit identity) |
| `GET /v1/loans/:id/journal_entries.json` | always empty (matches the sunset upstream) |
| `GET /v1/partners.json`, `/v1/partners/:ids.json` | partner list + detail |
| `GET /v1/lenders/:ids.json`, `/v1/lenders/:id/loans.json`, `/v1/lenders/:id/teams.json` | ids are our user ids, optionally `u`-prefixed |
| `GET /v1/teams/search.json`, `/v1/teams/:ids.json`, `/v1/teams/:id/loans.json` | team search/detail/loans |
| `GET /v1/templates/images.json` | image URL template descriptor |
| `GET /v1/my/{lender,loans,teams,expected_repayments}.json` | **bearer required** |

Collections wrap as `{"paging": {page,total,page_size,pages}, "<key>": [...]}`;
batch `:ids` endpoints omit `paging`; `ids_only=true` returns a flat id array.
Errors use `{"code": "org.kiva.<Type>", "message": ...}`.

### Modern GraphQL (`/graphql`)

`Query.lend`: `loan(id)`, `loans(filters, sortBy, limit, offset) → LoanBasicCollection{totalCount, values}`, `sector`, `activity`.
`Query.my` (auth): `userAccount`, `lender`, `loans`, `teams`.
`Query.shop` (auth): `basket`.
`Mutation.shop` (auth): `createBasket`, `updateLoanReservation`, `checkout`.

`LoanBasic` is an interface resolved to `LoanPartner` / `LoanDirect` by
distribution model. Custom scalars: `Money` (decimal string), `Date`, `Url`.
Enum values use Kiva's lowercase/camelCase names (e.g. `fieldPartner`, `payingBack`).

### Auth

`POST /oauth/token` supports `authorization_code`, `refresh_token`, and `password`
grants, returning `{access_token, token_type: "bearer", expires_in, refresh_token}`.
Pass `Authorization: Bearer <access_token>` to the `my/*` REST routes and the
GraphQL `my`/`shop` subtrees. Tokens are stateless `Phoenix.Token`s (demo-grade).

## Field mapping highlights

| Concept | Our model | Kiva legacy | Kiva GraphQL |
|---|---|---|---|
| Money | `*_cents` (int) | dollars (number) | `Money` string `"x.xx"` |
| Loan status | `fundraising/funded/funded_disbursed/repaying/delinquent/completed/defaulted` | `fundraising/funded/in_repayment/paid/defaulted` | `LoanStatusEnum` (`payingBack`, `ended`, …) |
| Distribution | `trust_model` | `partner_id` present ⇒ field partner | `DistributionModelEnum` |
| Gender | `borrowers.gender` | `"M"`/`"F"` | `GenderEnum` |
| Geo | `country_code` | `location{country, geo{pairs}}` | `Geocode{country{isoCode,region}}` |
| Text | `*_lc` sidecars | `description{languages, texts{}}` | `description` (resolved locale) |
| Lenders | `lendings` table | `lenders[]` | `LenderCollection` |

## Known gaps / deliberate stubs

Where our model has no equivalent data, fields are stubbed rather than omitted, so
the response *shape* stays compatible:

- **Partner risk metrics** (`rating`, `delinquency_rate`, `default_rate`,
  `loans_posted`, `total_amount_raised`) — `0`/`"0.0"`; we don't model MFI risk.
- **Lender profile extras** (`whereabouts`, `occupation`, `loan_because`) — `null`.
- **Journal entries / updates** — empty, matching the decommissioned real upstream.
- **Image URLs** — `image{id, template_id}` is shaped correctly and
  `templates/images.json` returns a pattern, but ids are synthesized; the borrower
  photo privacy rule (visible only while fundraising) is preserved.
- **`region`/country tables** — a static map in the adapter covers the seeded
  countries plus common Kiva markets; unknown ISO codes fall back to the code.
- **Gender backfill** — the demo seed sets all borrowers `female`; `gender=male`
  is wired and correct but returns no rows until male borrowers exist.
- **`status` enum** — we accept the fuller historical enum (the live upstream is
  degraded to `fundraising/funded/expired`); clients never object to *more*
  working values.

## Verify

```bash
mix ecto.migrate && mix run priv/repo/seeds.exs   # gender backfill
mix phx.server
curl 'localhost:4000/v1/loans/search.json?status=fundraising&gender=female&per_page=2'
curl localhost:4000/v1/loans/<id>.json             # terms{}, borrowers[], description.texts{}
curl -X POST localhost:4000/graphql -H 'content-type: application/json' \
  -d '{"query":"{ lend { loans(filters:{status:fundraising}, limit:2){ totalCount values { id loanAmount ... on LoanPartner { partnerName } } } } }"}'
mix test test/kiva_web/kiva_v1 test/kiva_web/kiva_graphql
```
