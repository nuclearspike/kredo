defmodule KivaWeb.KivaV1.PartnerController do
  @moduledoc "Legacy Kiva REST v1 partner endpoints."
  use KivaWeb, :controller

  alias Kiva.Partners
  alias KivaWeb.KivaCompat.Paging
  alias KivaWeb.KivaV1.PartnerJSON

  action_fallback KivaWeb.KivaV1.FallbackController

  # Kiva returns all partners on one large page.
  def index(conn, params) do
    locale = locale(params)
    {page, per_page} = Paging.page_params(params, 500)
    {partners, total} = Partners.kiva_list(per_page, Paging.offset(page, per_page))
    rows = Enum.map(partners, &PartnerJSON.partner(&1, %{locale: locale}))
    json(conn, Paging.envelope("partners", rows, total, page, per_page, %{}, & &1.id))
  end

  def show(conn, %{"ids" => ids} = params) do
    locale = locale(params)
    partners = Partners.kiva_by_ids(Paging.parse_ids(ids))
    data = Enum.map(partners, &PartnerJSON.detail(&1, %{locale: locale}))
    json(conn, Paging.batch("partners", data))
  end

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])
end
