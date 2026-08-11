defmodule Kiva.Lending.LoanLc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "loans_lc" do
    field :title, :string
    field :short_description, :string
    field :borrower_story, :string
    field :loan_use, :string
    field :repayment_summary, :string
    field :risk_summary_public, :string
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :translation_status, :string, default: "draft"
    field :translated_from_lc_id, :integer
    field :version, :integer, default: 1
    field :source_hash, :string
    belongs_to :loan, Kiva.Lending.Loan
    timestamps(type: :utc_datetime)
  end

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :loan_id,
      :title,
      :short_description,
      :borrower_story,
      :loan_use,
      :repayment_summary,
      :risk_summary_public,
      :locale_code,
      :is_source,
      :source_locale_code,
      :translation_status,
      :translated_from_lc_id,
      :version,
      :source_hash
    ])
    |> validate_required([:loan_id, :locale_code, :translation_status])
  end
end
