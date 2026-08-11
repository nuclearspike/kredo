defmodule Kiva.Audit.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [inserted_at: :inserted_at, updated_at: false]
  schema "audit_events" do
    field :actor_user_id, :integer
    field :actor_role, :string
    field :event_type, :string
    field :target_type, :string
    field :target_id, :string
    field :summary, :string
    field :metadata, :map, default: %{}
    field :inserted_at, :utc_datetime
  end

  def changeset(e, attrs) do
    e
    |> cast(attrs, [
      :actor_user_id,
      :actor_role,
      :event_type,
      :target_type,
      :target_id,
      :summary,
      :metadata
    ])
    |> validate_required([:event_type])
  end
end
