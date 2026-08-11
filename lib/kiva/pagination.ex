defmodule Kiva.Pagination do
  @moduledoc """
  Keyset (cursor) pagination helpers. A cursor is an `{inserted_at, id}` pair
  encoded as a URL-safe base64 string. Keyset stays fast at any depth (unlike
  OFFSET), at the cost of prev/next navigation instead of jump-to-page.

  The WHERE fragment is written inline in each context (it needs the query's own
  binding); this module only handles the cursor codec + page limit.
  """
  @default_limit 24

  def default_limit, do: @default_limit

  def page_limit(filters) when is_map(filters),
    do: filters[:limit] || filters["limit"] || @default_limit

  def page_limit(_), do: @default_limit

  def encode(nil), do: nil
  def encode({%DateTime{} = ts, id}), do: enc(DateTime.to_iso8601(ts), id)
  def encode({%NaiveDateTime{} = ts, id}), do: enc(NaiveDateTime.to_iso8601(ts), id)
  defp enc(iso, id), do: Base.url_encode64("#{iso}|#{id}", padding: false)

  def decode(nil), do: nil
  def decode(""), do: nil

  def decode(cursor) when is_binary(cursor) do
    with {:ok, raw} <- Base.url_decode64(cursor, padding: false),
         [iso, id] <- String.split(raw, "|", parts: 2),
         {n, ""} <- Integer.parse(id),
         {:ok, ts, _} <- DateTime.from_iso8601(iso) do
      {ts, n}
    else
      _ -> nil
    end
  end

  def decode(_), do: nil
end
