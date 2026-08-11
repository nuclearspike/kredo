defmodule Kiva.Portfolio.Lend do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [inserted_at: :inserted_at, updated_at: false]
  schema "lendings" do
    field :user_id, :integer
    field :amount_cents, :integer, default: 2500
    field :inserted_at, :utc_datetime
    belongs_to :loan, Kiva.Lending.Loan
    field :lending_team_id, :integer
  end

  def changeset(l, attrs) do
    l
    |> cast(attrs, [:user_id, :loan_id, :lending_team_id, :amount_cents])
    |> validate_required([:loan_id, :amount_cents])
    |> Kiva.Money.validate_lend_amount(:amount_cents)
  end
end
