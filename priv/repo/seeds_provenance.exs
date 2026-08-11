# Warm fabricated provenance for a browse-path slice of loans (demo data).
#
#   mix run priv/repo/seeds_provenance.exs                # newest 2000 public loans
#   SEED_PROVENANCE_LIMIT=500 mix run priv/repo/seeds_provenance.exs
#
# The dataset holds ~1.1M loans, so full eager seeding is deliberately NOT done:
# any other listing materializes its trail lazily on first staff/admin view via
# Kiva.Provenance.Fabricator.ensure!/1. Re-running re-fabricates the slice
# deterministically (delete + rebuild per loan).
import Ecto.Query

alias Kiva.{Repo, Provenance}
alias Kiva.Lending.Loan

limit = String.to_integer(System.get_env("SEED_PROVENANCE_LIMIT", "2000"))

ids =
  Repo.all(
    from l in Loan,
      where: l.status in ~w(fundraising funded funded_disbursed repaying delinquent completed),
      order_by: [desc: l.inserted_at, desc: l.id],
      limit: ^limit,
      select: l.id
  )

total =
  ids
  |> Enum.chunk_every(100)
  |> Enum.reduce(0, fn chunk, acc ->
    loans =
      Repo.all(from(l in Loan, where: l.id in ^chunk))
      |> Repo.preload([:translations, :borrower, partner: :translations])

    acc + (loans |> Enum.map(&Provenance.Fabricator.fabricate!/1) |> Enum.sum())
  end)

IO.puts("== Seeded provenance for #{length(ids)} loans (#{total} events) ==")
