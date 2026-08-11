defmodule Kiva.Teams.TeamLc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lending_teams_lc" do
    field :name, :string
    field :tagline, :string
    field :description, :string
    field :welcome_post_template, :string
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :translation_status, :string, default: "draft"
    field :translated_from_lc_id, :integer
    field :version, :integer, default: 1
    field :source_hash, :string
    belongs_to :lending_team, Kiva.Teams.Team
    timestamps(type: :utc_datetime)
  end

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :lending_team_id,
      :name,
      :tagline,
      :description,
      :welcome_post_template,
      :locale_code,
      :is_source,
      :source_locale_code,
      :translation_status,
      :version
    ])
    |> validate_required([:lending_team_id, :locale_code])
  end
end
