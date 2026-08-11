defmodule KivaWeb.KivaV1.TeamJSON do
  @moduledoc "Legacy Kiva REST v1 team shaping."
  alias KivaWeb.KivaCompat.Mapping

  def team(t, ctx \\ %{}) do
    locale = ctx[:locale] || "en"
    lc = Mapping.resolve(t.translations, locale)

    %{
      id: t.id,
      shortname: t.slug,
      name: (lc && lc.name) || t.slug,
      category: "Common Interest",
      whereabouts: nil,
      loan_because: lc && lc.tagline,
      description: lc && lc.description,
      website_url: nil,
      team_since: Mapping.iso8601(t.inserted_at),
      membership_type: membership(t.visibility),
      member_count: t.member_count,
      loan_count: ctx[:loan_count] || 0,
      loaned_amount: Mapping.money_number(t.total_lent_cents)
    }
    |> maybe_put(:image, image(t))
  end

  defp membership("public"), do: "open"
  defp membership(_), do: "closed"

  defp image(%{image_url: nil}), do: nil
  defp image(%{image_url: url}), do: %{id: :erlang.phash2(url, 1_000_000_000), template_id: 1}

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
