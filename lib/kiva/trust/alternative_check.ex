defmodule Kiva.Trust.AlternativeCheck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alternative_checks" do
    field :check_type, :string
    field :status, :string, default: "passed"
    field :detail, :string
    field :borrower_id, :integer
    belongs_to :loan, Kiva.Lending.Loan
    timestamps(type: :utc_datetime)
  end

  def changeset(c, attrs) do
    c
    |> cast(attrs, [:loan_id, :borrower_id, :check_type, :status, :detail])
    |> validate_required([:loan_id, :check_type])
  end
end
