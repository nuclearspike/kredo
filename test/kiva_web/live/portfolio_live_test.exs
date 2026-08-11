defmodule KivaWeb.PortfolioLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures
  alias Kiva.{Portfolio, Accounts, Lending}

  setup do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "plr@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, loan.id, 2500)
    Lending.record_repayment(loan.id)
    %{lender: lender, loan: loan}
  end

  test "lender sees their impact with returns", %{conn: conn, lender: lender} do
    conn = log_in(conn, lender)
    {:ok, _view, html} = live(conn, ~p"/portfolio")
    assert html =~ "My impact"
    assert html =~ "Weaving loan"
    assert html =~ "You lent"
    assert html =~ "Repaid to you"
  end

  test "URL filters scope the loans list and show removable chips", %{
    conn: conn,
    lender: lender,
    loan: loan
  } do
    conn = log_in(conn, lender)

    {:ok, _view, html} = live(conn, ~p"/portfolio?country=#{loan.country_code}")
    assert html =~ "Weaving loan"
    assert html =~ "Clear all"

    {:ok, _view, html} = live(conn, ~p"/portfolio?country=US")
    assert html =~ "No loans match your filters."
  end

  test "group-by renders rollup rows that drill down into a filter", %{conn: conn, lender: lender} do
    conn = log_in(conn, lender)
    {:ok, view, html} = live(conn, ~p"/portfolio?group=country")

    assert html =~ "phx-click=\"drill\""
    assert html =~ "lending"

    html = view |> element("button[phx-click=drill]") |> render_click()
    assert_patch(view)
    assert html =~ "Weaving loan"
  end

  test "the repayment chart renders for a repaying loan", %{conn: conn, lender: lender} do
    %{loan: repaying} = loan_fixture(%{funded_amount_cents: 100_000})
    Portfolio.lend(lender, repaying.id, 10_000)
    {:ok, _} = repaying |> Ecto.Changeset.change(status: "repaying") |> Kiva.Repo.update()

    conn = log_in(conn, lender)
    {:ok, _view, html} = live(conn, ~p"/portfolio")

    assert html =~ "Money coming back"
    assert html =~ "View as table"
    assert html =~ "Scheduled (estimate)"
  end

  test "a lender with no lendings sees the empty-state invitation", %{conn: conn} do
    {:ok, fresh} =
      Accounts.register_user(%{email: "fresh@kredo.test", password: "password", role: "lender"})

    conn = log_in(conn, fresh)
    {:ok, _view, html} = live(conn, ~p"/portfolio")
    assert html =~ "Your impact starts here"
    assert html =~ "Browse loans"
  end

  test "a non-lender cannot reach /portfolio", %{conn: conn} do
    conn = log_in(conn, user_fixture(%{role: "borrower"}))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/portfolio")
  end
end
