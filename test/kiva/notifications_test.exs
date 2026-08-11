defmodule Kiva.NotificationsTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Notifications, Portfolio, Lending, Accounts}

  setup do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "nt@kredo.test", password: "password", role: "lender"})

    %{loan: loan, lender: lender}
  end

  test "a repayment notifies the loan's lenders", %{loan: loan, lender: lender} do
    Portfolio.lend(lender, loan.id, 2500)
    Lending.record_repayment(loan.id)
    assert Notifications.unread_count(lender.id) >= 1
    assert [%{type: "repayment"} | _] = Notifications.list_for_user(lender.id)
  end

  test "fully funding notifies lenders", %{loan: loan, lender: lender} do
    Portfolio.lend(lender, loan.id, 60_000)
    assert Enum.any?(Notifications.list_for_user(lender.id), &(&1.type == "loan_funded"))
  end

  test "mark_all_read clears the unread count", %{loan: loan, lender: lender} do
    Portfolio.lend(lender, loan.id, 2500)
    Lending.record_repayment(loan.id)
    Notifications.mark_all_read(lender.id)
    assert Notifications.unread_count(lender.id) == 0
  end
end
