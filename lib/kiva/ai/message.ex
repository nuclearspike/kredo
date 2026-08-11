defmodule Kiva.AI.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [inserted_at: :inserted_at, updated_at: false]
  schema "ai_messages" do
    field :role, :string
    field :mode, :string
    field :content, :string
    field :metadata, :map, default: %{}
    field :inserted_at, :utc_datetime
    belongs_to :ai_conversation, Kiva.AI.Conversation
  end

  def changeset(m, attrs) do
    m
    |> cast(attrs, [:ai_conversation_id, :role, :mode, :content, :metadata])
    |> validate_required([:ai_conversation_id, :role])
  end
end
