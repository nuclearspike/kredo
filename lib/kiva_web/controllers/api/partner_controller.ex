defmodule KivaWeb.Api.PartnerController do
  @moduledoc "Public localized partner profiles."
  use KivaWeb, :controller

  alias Kiva.Partners
  alias KivaWeb.Api.Serializer

  action_fallback KivaWeb.Api.FallbackController

  def show(conn, %{"slug" => slug} = params) do
    case Partners.get_localized_partner(slug, locale(params)) do
      nil -> {:error, :not_found}
      partner -> json(conn, %{data: Serializer.partner(partner)})
    end
  end

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])
end
