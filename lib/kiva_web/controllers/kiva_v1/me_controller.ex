defmodule KivaWeb.KivaV1.MeController do
  @moduledoc "Authenticated Kiva-compat `my/*` REST endpoints (bearer token required)."
  use KivaWeb, :controller

  alias Kiva.{Lending, Teams}
  alias KivaWeb.KivaCompat.Paging
  alias KivaWeb.KivaV1.{LenderJSON, LoanJSON, TeamJSON}

  def lender(conn, _params) do
    u = conn.assigns.current_user

    json(conn, %{
      lenders: [LenderJSON.detail(u, %{loan_count: Lending.kiva_lender_loan_count(u.id)})]
    })
  end

  def loans(conn, params) do
    u = conn.assigns.current_user
    locale = Kiva.Localization.normalize(params["locale"])
    {page, per_page} = Paging.page_params(params)
    {loans, total} = Lending.kiva_lender_loans(u.id, per_page, Paging.offset(page, per_page))
    rows = Enum.map(loans, &LoanJSON.summary(&1, %{locale: locale}))
    json(conn, Paging.envelope("loans", rows, total, page, per_page, %{}, & &1.id))
  end

  def teams(conn, params) do
    u = conn.assigns.current_user
    locale = Kiva.Localization.normalize(params["locale"])
    {page, per_page} = Paging.page_params(params)
    teams = Teams.kiva_user_teams(u.id)
    rows = Enum.map(teams, &TeamJSON.team(&1, %{locale: locale}))
    json(conn, Paging.envelope("teams", rows, length(rows), page, per_page, %{}, & &1.id))
  end

  @doc "Stubbed (we don't model a forward repayment calendar across all loans yet)."
  def expected_repayments(conn, _params), do: json(conn, %{expected_repayments: []})
end
