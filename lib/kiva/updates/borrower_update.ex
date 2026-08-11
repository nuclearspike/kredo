defmodule Kiva.Updates.BorrowerUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(update outcome)

  schema "borrower_updates" do
    field :kind, :string, default: "update"
    field :source_locale_code, :string, default: "en"
    field :borrower_id, :integer
    field :author_user_id, :integer
    belongs_to :loan, Kiva.Lending.Loan
    has_many :translations, Kiva.Updates.BorrowerUpdateLc, foreign_key: :borrower_update_id
    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds

  def changeset(u, attrs) do
    u
    |> cast(attrs, [:loan_id, :borrower_id, :author_user_id, :kind, :source_locale_code])
    |> validate_required([:loan_id, :kind])
    |> validate_inclusion(:kind, @kinds)
  end
end
