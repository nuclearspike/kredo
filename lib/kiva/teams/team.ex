defmodule Kiva.Teams.Team do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :slug}
  schema "lending_teams" do
    field :slug, :string
    field :owner_user_id, :integer
    field :visibility, :string, default: "public"
    field :image_url, :string
    field :image_source, :string, default: "placeholder"
    field :default_locale_code, :string, default: "en"
    field :member_count, :integer, default: 0
    field :total_lent_cents, :integer, default: 0
    has_many :translations, Kiva.Teams.TeamLc, foreign_key: :lending_team_id
    has_many :posts, Kiva.Teams.TeamPost, foreign_key: :lending_team_id
    timestamps(type: :utc_datetime)
  end

  def changeset(t, attrs) do
    t
    |> cast(attrs, [
      :slug,
      :owner_user_id,
      :visibility,
      :image_url,
      :image_source,
      :default_locale_code,
      :member_count,
      :total_lent_cents
    ])
    |> validate_required([:slug])
    |> validate_inclusion(:visibility, ~w(public private invite_only))
    |> unique_constraint(:slug)
  end
end
