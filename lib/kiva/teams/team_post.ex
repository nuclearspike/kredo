defmodule Kiva.Teams.TeamPost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "team_posts" do
    field :moderation_status, :string, default: "approved"
    field :source_locale_code, :string, default: "en"
    field :author_user_id, :integer
    belongs_to :lending_team, Kiva.Teams.Team
    has_many :translations, Kiva.Teams.TeamPostLc, foreign_key: :team_post_id
    timestamps(type: :utc_datetime)
  end

  def changeset(p, attrs) do
    p
    |> cast(attrs, [:lending_team_id, :author_user_id, :moderation_status, :source_locale_code])
    |> validate_required([:lending_team_id])
  end
end
