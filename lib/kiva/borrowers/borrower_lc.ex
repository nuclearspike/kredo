defmodule Kiva.Borrowers.BorrowerLc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "borrowers_lc" do
    field :display_name, :string
    field :public_bio, :string
    field :business_summary, :string
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :translation_status, :string, default: "published"
    field :translated_from_lc_id, :integer
    field :version, :integer, default: 1
    field :source_hash, :string
    belongs_to :borrower, Kiva.Borrowers.Borrower
    timestamps(type: :utc_datetime)
  end

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :borrower_id,
      :display_name,
      :public_bio,
      :business_summary,
      :locale_code,
      :is_source,
      :source_locale_code,
      :translation_status,
      :version
    ])
    |> validate_required([:borrower_id, :display_name, :locale_code])
  end
end
