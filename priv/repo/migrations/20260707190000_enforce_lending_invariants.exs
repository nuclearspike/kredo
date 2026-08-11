defmodule Kiva.Repo.Migrations.EnforceLendingInvariants do
  @moduledoc """
  Lending money moves in whole $25 units (2500 cents). Backfills the demo data
  that predates the rule (percentage-derived funded totals, arbitrarily split
  lend rows), then adds CHECK constraints so no writer — changeset, raw SQL, or
  out-of-repo bulk script — can reintroduce off-unit amounts.

  Loan *status* gating (lend only while fundraising) is deliberately NOT a
  constraint: lends on repaying/completed loans are valid history.
  """
  use Ecto.Migration

  def up do
    # Lends and basket items: snap to the nearest positive $25 unit.
    execute """
    UPDATE lendings
    SET amount_cents = GREATEST(2500, (ROUND(amount_cents / 2500.0) * 2500)::bigint)
    WHERE amount_cents <= 0 OR amount_cents % 2500 <> 0
    """

    execute """
    UPDATE basket_items
    SET amount_cents = GREATEST(2500, (ROUND(amount_cents / 2500.0) * 2500)::bigint)
    WHERE amount_cents <= 0 OR amount_cents % 2500 <> 0
    """

    # Funded totals: floor to a unit (never flips a fundraising loan to fully
    # funded), capped at the loan amount.
    execute """
    UPDATE loans
    SET funded_amount_cents = LEAST(loan_amount_cents, (FLOOR(funded_amount_cents / 2500.0) * 2500)::bigint)
    WHERE funded_amount_cents % 2500 <> 0
    """

    # Team lifetime totals are derived from lends; recompute after the snap.
    execute """
    UPDATE lending_teams
    SET total_lent_cents = COALESCE(
      (SELECT SUM(l.amount_cents) FROM lendings l WHERE l.lending_team_id = lending_teams.id), 0)
    """

    create constraint(:lendings, :lendings_amount_in_25_dollar_units,
             check: "amount_cents > 0 AND amount_cents % 2500 = 0"
           )

    create constraint(:basket_items, :basket_items_amount_in_25_dollar_units,
             check: "amount_cents > 0 AND amount_cents % 2500 = 0"
           )

    create constraint(:loans, :loans_amounts_in_25_dollar_units,
             check: "loan_amount_cents % 2500 = 0 AND funded_amount_cents % 2500 = 0"
           )
  end

  def down do
    drop constraint(:lendings, :lendings_amount_in_25_dollar_units)
    drop constraint(:basket_items, :basket_items_amount_in_25_dollar_units)
    drop constraint(:loans, :loans_amounts_in_25_dollar_units)
  end
end
