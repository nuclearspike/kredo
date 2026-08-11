defmodule Kiva.Taxonomy.SectorLc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sectors_lc" do
    field :name, :string
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :translation_status, :string, default: "published"
    field :translated_from_lc_id, :integer
    field :version, :integer, default: 1
    field :source_hash, :string
    belongs_to :sector, Kiva.Taxonomy.Sector
    timestamps(type: :utc_datetime)
  end

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :sector_id,
      :name,
      :locale_code,
      :is_source,
      :source_locale_code,
      :translation_status,
      :version
    ])
    |> validate_required([:sector_id, :name, :locale_code])
  end
end
