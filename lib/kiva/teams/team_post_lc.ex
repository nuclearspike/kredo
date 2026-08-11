defmodule Kiva.Teams.TeamPostLc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "team_posts_lc" do
    field :body, :string
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :translation_status, :string, default: "draft"
    field :translated_from_lc_id, :integer
    field :version, :integer, default: 1
    field :source_hash, :string
    belongs_to :team_post, Kiva.Teams.TeamPost
    timestamps(type: :utc_datetime)
  end

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :team_post_id,
      :body,
      :locale_code,
      :is_source,
      :source_locale_code,
      :translation_status,
      :translated_from_lc_id,
      :version,
      :source_hash
    ])
    |> validate_required([:team_post_id, :locale_code])
  end
end
