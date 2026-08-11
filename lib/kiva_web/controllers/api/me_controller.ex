defmodule KivaWeb.Api.MeController do
  @moduledoc """
  The authenticated lender/borrower's own data — the same loans, teams, and
  portfolio they see when logged in. Requires a valid bearer token (gated by the
  `:api_authenticated` pipeline).
  """
  use KivaWeb, :controller

  alias Kiva.{Borrowers, Lending, Portfolio, Teams}
  alias KivaWeb.Api.Serializer

  def show(conn, _params) do
    json(conn, %{data: Serializer.user(conn.assigns.current_user)})
  end

  def loans(conn, params) do
    user = conn.assigns.current_user
    locale = locale(params)

    borrower_loans =
      case Borrowers.get_by_user(user.id) do
        nil -> []
        b -> Lending.list_loans_for_borrower(b.id, locale) |> Enum.map(&Serializer.loan_profile/1)
      end

    json(conn, %{
      data: %{
        lendings: Portfolio.list_user_lendings_localized(user.id, locale),
        borrower_loans: borrower_loans
      }
    })
  end

  def teams(conn, params) do
    user = conn.assigns.current_user
    json(conn, %{data: Teams.list_user_teams(user.id, locale(params))})
  end

  def portfolio(conn, _params) do
    s = Portfolio.portfolio_summary(conn.assigns.current_user.id)

    json(conn, %{
      data: Map.take(s, [:count, :total_cents, :returned_cents, :available_to_relend_cents])
    })
  end

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])
end
