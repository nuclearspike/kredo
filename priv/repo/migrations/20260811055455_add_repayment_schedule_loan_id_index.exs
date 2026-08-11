defmodule Kiva.Repo.Migrations.AddRepaymentScheduleLoanIdIndex do
  @moduledoc """
  Every schedule lookup goes through `loan_id`, which carried no index — the
  lender portfolio chart, the borrower portal, and the partner repayment queue
  all sequential-scanned the whole schedules table. At demo scale (98k schedules)
  that is the difference between a ~95ms and a ~10ms chart query.
  """
  use Ecto.Migration

  def change do
    create index(:repayment_schedules, [:loan_id])
  end
end
