defmodule Kiva.BasketTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Basket, Accounts, Commands}

  setup do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "bk@kredo.test", password: "password", role: "lender"})

    %{loan: loan, lender: lender}
  end

  test "add upserts the amount and lists localized items", %{loan: loan, lender: lender} do
    Basket.add(lender.id, loan.id, 2500)
    Basket.add(lender.id, loan.id, 5000)
    assert Basket.count(lender.id) == 1
    assert Basket.total_cents(lender.id) == 5000
    assert [%{title: "Weaving loan", amount_cents: 5000}] = Basket.items(lender.id, "en")
  end

  test "add_loan_to_basket runs through the registry (lender only)", %{loan: loan, lender: lender} do
    assert {:ok, _} =
             Commands.execute("add_loan_to_basket", lender, %{
               "loan_id" => to_string(loan.id),
               "amount_cents" => "5000"
             })

    assert Basket.total_cents(lender.id) == 5000

    {:ok, partner} =
      Accounts.register_user(%{email: "bkp@kredo.test", password: "password", role: "partner"})

    assert {:error, {:forbidden, "add_loan_to_basket", "partner"}} =
             Commands.execute("add_loan_to_basket", partner, %{"loan_id" => to_string(loan.id)})
  end

  test "remove clears an item", %{loan: loan, lender: lender} do
    Basket.add(lender.id, loan.id, 2500)
    Basket.remove(lender.id, loan.id)
    assert Basket.count(lender.id) == 0
  end
end
