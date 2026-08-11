defmodule Kiva.Moderation do
  @moduledoc """
  Mock content moderation for cross-language encouragement. Rule-based stand-in
  for an AI moderator: it never silently rewrites — it approves, asks for a
  rewrite, or blocks with a gentle reason.
  """
  @blocked ~w(scam idiot stupid loser)
  @solicitation ["send me money", "give me money", "wire me", "venmo", "cashapp"]

  @spec moderate(String.t()) :: :approved | {:rewrite, String.t()} | {:rejected, String.t()}
  def moderate(text) when is_binary(text) do
    norm = String.downcase(text)
    trimmed = String.trim(text)

    cond do
      String.length(trimmed) < 2 ->
        {:rejected, "The message is too short."}

      Enum.any?(@blocked, &String.contains?(norm, &1)) ->
        {:rejected, "The message contains unkind language. Please rephrase."}

      Enum.any?(@solicitation, &String.contains?(norm, &1)) ->
        {:rejected, "Messages can't request money or off-platform payment."}

      String.upcase(text) == text and String.length(trimmed) > 12 ->
        {:rewrite, "Consider not using all capitals — it can read as shouting."}

      true ->
        :approved
    end
  end

  def moderate(_), do: {:rejected, "Empty message."}
end
