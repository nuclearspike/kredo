defmodule Kiva.AI.ToolCall do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [inserted_at: :inserted_at, updated_at: false]
  schema "ai_tool_calls" do
    field :tool_type, :string
    field :schema_surface, :string
    field :operation_name, :string
    field :allowed, :boolean, default: true
    field :denial_reason, :string
    field :request, :map, default: %{}
    field :response_summary, :string
    field :inserted_at, :utc_datetime
    belongs_to :ai_conversation, Kiva.AI.Conversation
  end

  def changeset(t, attrs) do
    t
    |> cast(attrs, [
      :ai_conversation_id,
      :tool_type,
      :schema_surface,
      :operation_name,
      :allowed,
      :denial_reason,
      :request,
      :response_summary
    ])
    |> validate_required([:ai_conversation_id, :tool_type])
  end
end
