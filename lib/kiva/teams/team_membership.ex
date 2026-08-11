defmodule Kiva.Teams.TeamMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lending_team_memberships" do
    field :role, :string, default: "member"
    belongs_to :lending_team, Kiva.Teams.Team
    field :user_id, :integer
    timestamps(type: :utc_datetime)
  end

  def changeset(m, attrs) do
    m
    |> cast(attrs, [:lending_team_id, :user_id, :role])
    |> validate_required([:lending_team_id, :user_id])
  end
end
