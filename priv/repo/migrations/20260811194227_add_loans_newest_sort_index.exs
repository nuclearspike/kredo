defmodule Kiva.Repo.Migrations.AddLoansNewestSortIndex do
  @moduledoc """
  The default loan-search ordering is newest-first (`inserted_at DESC, id DESC`)
  under a multi-value status filter. The existing `(status, inserted_at, id)`
  index cannot serve that ordering across several statuses at once, so the
  planner sequential-scanned every loan and top-N sorted it: ~103ms at 1.1M
  loans, dwarfing the 2ms page fetch underneath.

  Indexing the sort columns alone lets the planner walk rows in output order and
  stop at the page size, applying the status filter as it goes — cheap here
  because nearly every loan passes that filter.
  """
  use Ecto.Migration

  def change do
    create index(:loans, ["inserted_at DESC", "id DESC"], name: :loans_newest_index)
  end
end
