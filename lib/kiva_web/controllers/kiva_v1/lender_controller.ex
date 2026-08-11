defmodule KivaWeb.KivaV1.LenderController do
  @moduledoc "Legacy Kiva REST v1 lender endpoints (ids are our user ids, optionally `u`-prefixed)."
  use KivaWeb, :controller

  alias Kiva.{Accounts, Lending}
  alias KivaWeb.KivaCompat.Paging
  alias KivaWeb.KivaV1.{LenderJSON, LoanJSON}

  action_fallback KivaWeb.KivaV1.FallbackController

  def show(conn, %{"ids" => ids}) do
    user_ids =
      ids |> String.split(",", trim: true) |> Enum.flat_map(&parse_uid/1) |> Enum.take(100)

    users = Accounts.get_users_by_ids(user_ids)

    data =
      Enum.map(users, fn u ->
        LenderJSON.detail(u, %{loan_count: Lending.kiva_lender_loan_count(u.id)})
      end)

    json(conn, Paging.batch("lenders", data))
  end

  def loans(conn, %{"id" => id} = params) do
    locale = locale(params)
    {page, per_page} = Paging.page_params(params)

    case parse_uid(id) do
      [uid] ->
        {loans, total} = Lending.kiva_lender_loans(uid, per_page, Paging.offset(page, per_page))
        rows = Enum.map(loans, &LoanJSON.summary(&1, %{locale: locale}))
        json(conn, Paging.envelope("loans", rows, total, page, per_page, %{}, & &1.id))

      [] ->
        {:error, :not_found}
    end
  end

  def teams(conn, %{"id" => id} = params) do
    locale = locale(params)
    {page, per_page} = Paging.page_params(params)

    case parse_uid(id) do
      [uid] ->
        teams = Kiva.Teams.kiva_user_teams(uid)
        rows = Enum.map(teams, &KivaWeb.KivaV1.TeamJSON.team(&1, %{locale: locale}))
        json(conn, Paging.envelope("teams", rows, length(rows), page, per_page, %{}, & &1.id))

      [] ->
        {:error, :not_found}
    end
  end

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])

  # Accept "5" or "u5" (our synthesized uid form). Returns [id] or [].
  defp parse_uid(s) do
    s = String.trim_leading(s, "u")

    case Integer.parse(s) do
      {n, _} -> [n]
      :error -> []
    end
  end
end
