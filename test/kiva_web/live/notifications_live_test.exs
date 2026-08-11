defmodule KivaWeb.NotificationsLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures
  alias Kiva.{Portfolio, Lending, Accounts, Notifications}

  test "lender sees their notification feed and viewing marks read", %{conn: conn} do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "nl@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, loan.id, 2500)
    Lending.record_repayment(loan.id)

    conn = log_in(conn, lender)
    {:ok, _view, html} = live(conn, ~p"/notifications")
    assert html =~ "Repayment received"
    assert Notifications.unread_count(lender.id) == 0
  end

  test "a partner can also reach their notification feed", %{conn: conn} do
    base = submitted_loan_fixture()
    Kiva.Lending.request_changes(base.draft.id, "fix the story")
    conn = log_in(conn, base.user)
    {:ok, _view, html} = live(conn, ~p"/notifications")
    assert html =~ "Changes requested"
  end
end
