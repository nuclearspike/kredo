defmodule KivaWeb.BasketLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures
  alias Kiva.{Basket, Accounts, Lending.Loan, Repo}

  setup do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "bl@kredo.test", password: "password", role: "lender"})

    Basket.add(lender.id, loan.id, 5000)
    %{loan: loan, lender: lender}
  end

  test "basket lists items and checking out lends all, clears, and lands on portfolio", %{
    conn: conn,
    lender: lender,
    loan: loan
  } do
    before = Repo.get!(Loan, loan.id).funded_amount_cents
    conn = log_in(conn, lender)
    {:ok, view, html} = live(conn, ~p"/basket")
    assert html =~ "Weaving loan"

    assert {:error, {:live_redirect, %{to: "/portfolio"}}} =
             view |> element("button[phx-click='checkout']") |> render_click()

    assert Basket.count(lender.id) == 0
    assert Repo.get!(Loan, loan.id).funded_amount_cents == before + 5000
  end
end
