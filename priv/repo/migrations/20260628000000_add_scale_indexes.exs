defmodule Kiva.Repo.Migrations.AddScaleIndexes do
  use Ecto.Migration

  # Indexes the hot queries need once the table reaches real volume
  # (~100K loans / ~4M total rows). See EXPLAIN before/after in the verify step.
  def change do
    # Browse: WHERE status = ? ORDER BY inserted_at DESC, id DESC (keyset)
    create index(:loans, [:status, :inserted_at, :id])
    create index(:loans, [:partner_id])
    create index(:loans, [:borrower_id])

    # Repayments-due / delinquency scans
    create index(:repayment_schedule_items, [:status])
    create index(:repayment_schedule_items, [:due_on])
    create index(:repayment_schedule_items, [:status, :due_on])

    # Borrower lookups by partner/sector
    create index(:borrowers, [:partner_id])
    create index(:borrowers, [:sector_id])

    # Portfolio (lendings by user, keyset) + team feed
    create index(:lendings, [:lending_team_id])
    create index(:lendings, [:user_id, :inserted_at, :id])

    # Translation review queue (ordered by inserted_at, so include it to avoid a sort)
    create index(:loans_lc, [:translation_status, :inserted_at, :id])
  end
end
