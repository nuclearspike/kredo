defmodule Kiva.Taxonomy.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activities" do
    field :key, :string
    belongs_to :sector, Kiva.Taxonomy.Sector
    has_many :translations, Kiva.Taxonomy.ActivityLc, foreign_key: :activity_id
    timestamps(type: :utc_datetime)
  end

  def changeset(a, attrs),
    do:
      a |> cast(attrs, [:key, :sector_id]) |> validate_required([:key]) |> unique_constraint(:key)
end
