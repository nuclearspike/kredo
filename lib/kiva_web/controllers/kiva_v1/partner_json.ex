defmodule KivaWeb.KivaV1.PartnerJSON do
  @moduledoc "Legacy Kiva REST v1 partner shaping. Risk metrics we don't model are stubbed."
  alias KivaWeb.KivaCompat.Mapping

  def partner(p, ctx \\ %{}) do
    locale = ctx[:locale] || "en"
    lc = Mapping.resolve(p.translations, locale)

    %{
      id: p.id,
      name: (lc && lc.name) || p.slug,
      status: p.status,
      # Kiva renders `rating` as a STRING for byte-parity.
      rating: "0.0",
      start_date: Mapping.iso8601(p.inserted_at),
      countries: countries(p),
      delinquency_rate: 0.0,
      default_rate: 0.0,
      total_amount_raised: ctx[:total_amount_raised] || 0,
      loans_posted: ctx[:loans_posted] || 0,
      charges_fees_and_interest: true
    }
    |> maybe_put(:image, image(p))
    |> maybe_put(:url, lc && lc.summary && nil)
  end

  @doc "Detail view adds the social-performance block."
  def detail(p, ctx \\ %{}) do
    p
    |> partner(ctx)
    |> Map.merge(%{portfolio_yield: 0.0, profitability: 0.0, social_performance_strengths: []})
  end

  defp countries(%{country_code: nil}), do: []

  defp countries(%{country_code: code}) do
    [
      %{
        iso_code: code,
        region: Mapping.region_name(code),
        name: Mapping.country_name(code),
        location: %{geo: geo(code)}
      }
    ]
  end

  defp geo(code) do
    case Mapping.legacy_location(%{country_code: code}) do
      %{geo: g} -> g
      _ -> nil
    end
  end

  defp image(%{image_url: nil}), do: nil
  defp image(%{image_url: url}), do: %{id: :erlang.phash2(url, 1_000_000_000), template_id: 1}

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
