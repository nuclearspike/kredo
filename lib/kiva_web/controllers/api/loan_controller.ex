defmodule KivaWeb.Api.LoanController do
  @moduledoc "Public localized loan search and profiles."
  use KivaWeb, :controller

  alias Kiva.Lending
  alias KivaWeb.Api.Serializer

  action_fallback KivaWeb.Api.FallbackController

  def index(conn, params) do
    filters =
      %{}
      |> maybe(:sector_id, parse_int(params["sector_id"]))
      |> maybe(:country_code, params["country_code"])
      |> maybe(:trust_model, params["trust_model"])
      |> maybe(:status, params["status"])
      |> maybe(:q, params["q"])

    data =
      Lending.list_localized_loans(locale(params), filters)
      |> Enum.map(&Serializer.loan_card/1)

    json(conn, %{data: data})
  end

  def show(conn, %{"slug" => slug} = params) do
    case Lending.get_localized_loan(slug, locale(params)) do
      nil -> {:error, :not_found}
      profile -> json(conn, %{data: Serializer.loan_profile(profile)})
    end
  end

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])

  defp maybe(map, _k, nil), do: map
  defp maybe(map, _k, ""), do: map
  defp maybe(map, k, v), do: Map.put(map, k, v)

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(i) when is_integer(i), do: i

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end
end
