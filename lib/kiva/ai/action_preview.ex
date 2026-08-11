defmodule Kiva.AI.ActionPreview do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_action_previews" do
    field :command_key, :string
    field :target_type, :string
    field :target_id, :string
    field :preview, :map, default: %{}
    field :risk_level, :string
    field :confirmed_at, :utc_datetime
    field :executed_at, :utc_datetime
    belongs_to :ai_conversation, Kiva.AI.Conversation
    timestamps(type: :utc_datetime)
  end

  def changeset(p, attrs) do
    p
    |> cast(attrs, [
      :ai_conversation_id,
      :command_key,
      :target_type,
      :target_id,
      :preview,
      :risk_level,
      :confirmed_at,
      :executed_at
    ])
    |> validate_required([:ai_conversation_id, :command_key])
  end
end
