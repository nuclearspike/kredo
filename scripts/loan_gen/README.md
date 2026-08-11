# loan_gen — the demo-data pipeline

Everything in here **fabricates** demo data. No real people, no real PII:
names come from synthetic per-country pools, listing text is LLM-written from
templates, and every portrait is AI-generated (gpt-image-1).

## Scale generation — no LLM, no API key

Fabricate any number of FK-consistent loans (plus users, schedules, lendings,
updates, notifications, audit samples) as CSVs, then bulk-load them with
`psql \copy`:

```bash
python3 build_csv.py --loans 250000 --users 50000   # deterministic under --seed
./load.sh                                            # KREDO_DB=kiva_dev by default
```

And/or a lean historical archive (loans + localized text only, dated
2013–2022, ~98% completed):

```bash
python3 build_1m.py --count 1000000
./load_1m.sh
```

Notes:

- Run **after** `mix ecto.setup` — the scripts read id maxima and slug→id
  maps from the database (pass `--db ''` to fall back to constants matching a
  fresh seed world; `KREDO_DB` overrides the database name).
- Text is drawn from the committed 208-template 5-locale pool
  ([pool.json](pool.json)), so generation is fully offline.
- Output CSVs land in `csv/` — **gitignored on purpose; never commit them**
  (a prior 1M-loan run weighed 2.6 GB).
- `build_1m.py` reuses existing borrowers — live from `--db`, else from
  [borrowers_export.csv](borrowers_export.csv). Regenerate that file with:

  ```bash
  psql kiva_dev -tA -F, -c "select b.id, b.partner_id, b.country_code, b.sector_id, b.preferred_locale_code, coalesce(lc.display_name,'') from borrowers b left join borrowers_lc lc on lc.borrower_id=b.id and lc.is_source" > borrowers_export.csv
  ```

## Seed-content refresh — optional, LLM-powered

The base demo world (200 rich loans) is seeded from JSON files committed under
`priv/repo/loan_data/`. These scripts regenerate that content — only needed to
*expand or refresh* it, never to run the app or the scale generator:

| Script | Produces | Needs |
|---|---|---|
| `pool_gen.py` | `pool.json` (208 five-locale text templates) | any OpenAI-compatible endpoint (`LLM_ENDPOINT`, `LLM_MODEL`; a small local model is plenty) |
| `params.py` | `priv/repo/loan_data/params.json` (200 loan parameter sets) | nothing (deterministic) |
| `content.py` | `priv/repo/loan_data/content.json` (rich 5-locale listing copy) | `OPENAI_API_KEY` |
| `posts.py` | `priv/repo/loan_data/team_posts.json` (team message boards) | `OPENAI_API_KEY` |
| `loan_images.py` | `priv/static/images/loans/*.jpg` (AI portraits) | `OPENAI_API_KEY` |

`priv/repo/seeds_loans.exs` reads the JSONs; `mix ecto.reset` rebuilds the
world from them.
