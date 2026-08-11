defmodule Kiva.Basket.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "basket_items" do
    field :user_id, :integer
    field :amount_cents, :integer, default: 2500
    belongs_to :loan, Kiva.Lending.Loan
    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:user_id, :loan_id, :amount_cents])
    |> validate_required([:user_id, :loan_id, :amount_cents])
    |> Kiva.Money.validate_lend_amount(:amount_cents)
  end
end
