defmodule Kiva.MessagingTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Messaging, Accounts}

  setup do
    base = borrower_user_fixture()

    {:ok, lender} =
      Accounts.register_user(%{
        email: "m-lender@kredo.test",
        password: "password",
        role: "lender"
      })

    Map.put(base, :lender, lender)
  end

  test "approved encouragement is translated into the borrower's language", %{
    lender: lender,
    loan: loan,
    borrower: borrower
  } do
    {:ok, _msg} = Messaging.create_encouragement(lender, loan.id, "Great work on your loan", "en")

    [m] = Messaging.list_for_borrower(borrower.id, "es")
    assert m.status == "machine"
    assert m.body =~ "[es←en]"
    refute m.fallback_used
  end

  test "unkind messages are blocked", %{lender: lender, loan: loan} do
    assert {:rejected, _} = Messaging.create_encouragement(lender, loan.id, "you idiot", "en")
    assert Messaging.list_for_loan(loan.id, "en") == []
  end
end
