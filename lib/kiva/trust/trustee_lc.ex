defmodule Kiva.Trust.TrusteeLc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trustees_lc" do
    field :name, :string
    field :bio, :string
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :translation_status, :string, default: "published"
    field :version, :integer, default: 1
    belongs_to :trustee, Kiva.Trust.Trustee
    timestamps(type: :utc_datetime)
  end

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :trustee_id,
      :name,
      :bio,
      :locale_code,
      :is_source,
      :source_locale_code,
      :translation_status,
      :version
    ])
    |> validate_required([:trustee_id, :locale_code])
  end
end
