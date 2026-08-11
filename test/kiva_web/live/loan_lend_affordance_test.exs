defmodule KivaWeb.LoanLendAffordanceTest do
  # No page may offer lend/basket controls for a loan that is not fundraising.
  use KivaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures

  setup %{conn: conn} do
    lender = user_fixture(%{role: "lender"})
    %{conn: log_in(conn, lender), lender: lender}
  end

  test "loan page hides the lend form when the loan is not fundraising", %{conn: conn} do
    loan = loan_fixture(%{status: "defaulted"}).loan
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")

    refute html =~ "lend_action"
    refute html =~ "drawer_support"
  end

  test "loan page still shows the lend form while fundraising", %{conn: conn} do
    loan = loan_fixture().loan
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")

    assert html =~ "lend_action"
  end

  test "browse drawer offers no Support button for a non-fundraising loan", %{conn: conn} do
    loan = loan_fixture(%{status: "defaulted"}).loan
    {:ok, view, _html} = live(conn, ~p"/loans?status=defaulted")

    html = render_click(view, "open_drawer", %{"slug" => loan.slug})
    refute html =~ "drawer_support"
  end

  test "browse drawer keeps the Support button for a fundraising loan", %{conn: conn} do
    loan = loan_fixture().loan
    {:ok, view, _html} = live(conn, ~p"/loans")

    html = render_click(view, "open_drawer", %{"slug" => loan.slug})
    assert html =~ "drawer_support"
  end
end
