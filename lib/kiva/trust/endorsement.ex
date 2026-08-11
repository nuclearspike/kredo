defmodule Kiva.Trust.Endorsement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trust_endorsements" do
    field :status, :string, default: "endorsed"
    field :source_locale_code, :string, default: "en"
    field :borrower_id, :integer
    belongs_to :loan, Kiva.Lending.Loan
    belongs_to :trustee, Kiva.Trust.Trustee
    has_many :translations, Kiva.Trust.EndorsementLc, foreign_key: :trust_endorsement_id
    timestamps(type: :utc_datetime)
  end

  def changeset(e, attrs) do
    e
    |> cast(attrs, [:loan_id, :trustee_id, :borrower_id, :status, :source_locale_code])
    |> validate_required([:loan_id])
  end
end
