defmodule Kiva.Trust.EndorsementLc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trust_endorsements_lc" do
    field :statement, :string
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :translation_status, :string, default: "published"
    field :version, :integer, default: 1
    belongs_to :trust_endorsement, Kiva.Trust.Endorsement
    timestamps(type: :utc_datetime)
  end

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :trust_endorsement_id,
      :statement,
      :locale_code,
      :is_source,
      :source_locale_code,
      :translation_status,
      :version
    ])
    |> validate_required([:trust_endorsement_id, :locale_code])
  end
end
