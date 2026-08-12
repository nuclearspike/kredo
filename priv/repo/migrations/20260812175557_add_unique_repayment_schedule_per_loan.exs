defmodule Kiva.Repo.Migrations.AddUniqueRepaymentSchedulePerLoan do
  use Ecto.Migration

  # Loan has_one :repayment_schedule, but the database allowed a loan several.
  # The disbursal and funding paths hold the loan row FOR UPDATE while they
  # check-then-insert, so a duplicate is unreachable through them; this makes
  # that structural rather than dependent on every future caller remembering
  # the lock. A second schedule would double what the borrower appears to owe
  # and what lenders are shown as coming back.
  #
  # Replaces the plain loan_id index rather than joining it: the unique index
  # serves the same lookups.
  def change do
    drop index(:repayment_schedules, [:loan_id])
    create unique_index(:repayment_schedules, [:loan_id])
  end
end
