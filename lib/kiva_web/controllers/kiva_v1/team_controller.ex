defmodule KivaWeb.KivaV1.TeamController do
  @moduledoc "Legacy Kiva REST v1 team endpoints."
  use KivaWeb, :controller

  alias Kiva.{Teams, Lending}
  alias KivaWeb.KivaCompat.Paging
  alias KivaWeb.KivaV1.{TeamJSON, LoanJSON}

  action_fallback KivaWeb.KivaV1.FallbackController

  def search(conn, params) do
    locale = locale(params)
    {page, per_page} = Paging.page_params(params)
    {teams, total} = Teams.kiva_search(params["q"], per_page, Paging.offset(page, per_page))
    rows = Enum.map(teams, &TeamJSON.team(&1, %{locale: locale}))
    json(conn, Paging.envelope("teams", rows, total, page, per_page, %{}, & &1.id))
  end

  def show(conn, %{"ids" => ids} = params) do
    locale = locale(params)
    teams = Teams.kiva_by_ids(Paging.parse_ids(ids))
    data = Enum.map(teams, &TeamJSON.team(&1, %{locale: locale}))
    json(conn, Paging.batch("teams", data))
  end

  def loans(conn, %{"id" => id} = params) do
    locale = locale(params)
    {page, per_page} = Paging.page_params(params)

    case Integer.parse(id) do
      {team_id, _} ->
        {loans, total} = Lending.kiva_team_loans(team_id, per_page, Paging.offset(page, per_page))
        rows = Enum.map(loans, &LoanJSON.summary(&1, %{locale: locale}))
        json(conn, Paging.envelope("loans", rows, total, page, per_page, %{}, & &1.id))

      :error ->
        {:error, :not_found}
    end
  end

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])
end
