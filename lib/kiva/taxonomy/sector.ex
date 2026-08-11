defmodule Kiva.Taxonomy.Sector do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sectors" do
    field :key, :string
    has_many :translations, Kiva.Taxonomy.SectorLc, foreign_key: :sector_id
    has_many :activities, Kiva.Taxonomy.Activity, foreign_key: :sector_id
    timestamps(type: :utc_datetime)
  end

  def changeset(s, attrs),
    do: s |> cast(attrs, [:key]) |> validate_required([:key]) |> unique_constraint(:key)
end
