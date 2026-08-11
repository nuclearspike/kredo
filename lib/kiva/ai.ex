defmodule Kiva.AI do
  @moduledoc """
  AI dialogue persistence: conversations, messages, tool calls, and action
  previews. Every chat session is one conversation; every GraphQL read or command
  preview/execute the assistant performs is recorded for admin reconstruction.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.AI.{Conversation, Message, ToolCall, ActionPreview}

  def start_conversation(attrs) do
    %Conversation{}
    |> Conversation.changeset(Map.new(attrs))
    |> Repo.insert!()
  end

  def get_conversation!(id), do: Repo.get!(Conversation, id) |> Repo.preload(:messages)

  def add_message(conversation_id, role, content, mode \\ nil, metadata \\ %{}) do
    %Message{}
    |> Message.changeset(%{
      ai_conversation_id: conversation_id,
      role: role,
      content: content,
      mode: mode,
      metadata: metadata
    })
    |> Repo.insert!()
  end

  def record_tool_call(conversation_id, attrs) do
    %ToolCall{}
    |> ToolCall.changeset(Map.put(Map.new(attrs), :ai_conversation_id, conversation_id))
    |> Repo.insert!()
  end

  def create_action_preview(conversation_id, attrs) do
    %ActionPreview{}
    |> ActionPreview.changeset(Map.put(Map.new(attrs), :ai_conversation_id, conversation_id))
    |> Repo.insert!()
  end

  def get_action_preview!(id), do: Repo.get!(ActionPreview, id)

  def mark_preview_confirmed(%ActionPreview{} = p) do
    p
    |> ActionPreview.changeset(%{confirmed_at: now()})
    |> Repo.update!()
  end

  def mark_preview_executed(%ActionPreview{} = p) do
    p
    |> ActionPreview.changeset(%{executed_at: now()})
    |> Repo.update!()
  end

  def list_tool_calls(conversation_id) do
    Repo.all(
      from t in ToolCall, where: t.ai_conversation_id == ^conversation_id, order_by: t.inserted_at
    )
  end

  @doc "Recent AI tool calls across all conversations (for the admin inspector)."
  def recent_tool_calls(limit \\ 25) do
    Repo.all(from t in ToolCall, order_by: [desc: t.inserted_at], limit: ^limit)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
