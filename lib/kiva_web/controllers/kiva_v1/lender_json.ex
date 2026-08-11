defmodule KivaWeb.KivaV1.LenderJSON do
  @moduledoc "Legacy Kiva REST v1 lender shaping. Anonymous lendings omit identity fields."
  alias KivaWeb.KivaCompat.Mapping

  @doc "Summary lender (in `/loans/:id/lenders.json`). `nil` user => anonymous."
  def summary(nil, _ctx), do: %{name: "Anonymous"}

  def summary(user, _ctx) do
    %{
      lender_id: user.id,
      uid: "u#{user.id}",
      name: user.display_name,
      whereabouts: nil,
      country_code: nil
    }
    |> maybe_put(:image, image(user))
  end

  @doc "Detail lender (`/lenders/:ids.json`)."
  def detail(user, ctx) do
    user
    |> summary(ctx)
    |> Map.merge(%{
      member_since: Mapping.iso8601(user.inserted_at),
      personal_url: nil,
      occupation: nil,
      loan_because: nil,
      occupational_info: nil,
      loan_count: ctx[:loan_count] || 0,
      invitee_count: 0
    })
  end

  defp image(%{avatar_url: nil}), do: nil
  defp image(%{avatar_url: url}), do: %{id: :erlang.phash2(url, 1_000_000_000), template_id: 1}
  defp image(_), do: nil

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
