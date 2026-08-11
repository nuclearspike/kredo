defmodule Kiva.AI.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_conversations" do
    field :user_id, :integer
    field :actor_role, :string, default: "public"
    field :locale_code, :string, default: "en"
    field :page_context, :map, default: %{}
    has_many :messages, Kiva.AI.Message, foreign_key: :ai_conversation_id
    timestamps(type: :utc_datetime)
  end

  def changeset(c, attrs) do
    c
    |> cast(attrs, [:user_id, :actor_role, :locale_code, :page_context])
    |> validate_required([:actor_role, :locale_code])
  end
end
