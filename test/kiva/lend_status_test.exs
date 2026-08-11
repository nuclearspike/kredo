defmodule Kiva.LendStatusTest do
  # Regression tests for the "lend only while fundraising" invariant: no surface
  # (command, preview, domain function, checkout replay) may record a lend or
  # basket a loan whose status is not "fundraising".
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Accounts, Basket, Commands, Portfolio, Repo}
  alias Kiva.Lending.Loan
  alias Kiva.Portfolio.Lend

  setup do
    {:ok, lender} =
      Accounts.register_user(%{
        email: "st-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    %{lender: lender}
  end

  for status <- ~w(funded repaying completed delinquent defaulted) do
    test "add_loan_to_basket rejects a #{status} loan", %{lender: lender} do
      loan = loan_fixture(%{status: unquote(status)}).loan

      assert {:error, _} =
               Commands.execute("add_loan_to_basket", lender, %{"loan_id" => to_string(loan.id)})

      assert Basket.count(lender.id) == 0
    end

    test "complete_demo_lend rejects a #{status} loan and records nothing", %{lender: lender} do
      loan = loan_fixture(%{status: unquote(status)}).loan
      before = Repo.get(Loan, loan.id).funded_amount_cents

      assert {:error, _} =
               Commands.execute("complete_demo_lend", lender, %{
                 "loan_id" => to_string(loan.id),
                 "amount_cents" => "2500"
               })

      assert Repo.get(Loan, loan.id).funded_amount_cents == before
      assert Repo.aggregate(Lend, :count) == 0
    end
  end

  test "preview also rejects non-fundraising loans, so chat fails early", %{lender: lender} do
    loan = loan_fixture(%{status: "completed"}).loan

    assert {:error, _} =
             Commands.preview("complete_demo_lend", lender, %{
               "loan_id" => to_string(loan.id),
               "amount_cents" => 2500
             })
  end

  test "Portfolio.lend refuses non-fundraising loans even when called directly", %{lender: lender} do
    loan = loan_fixture(%{status: "repaying"}).loan

    assert_raise ArgumentError, fn ->
      Portfolio.lend(lender, loan.id, 2500)
    end

    assert Repo.aggregate(Lend, :count) == 0
  end

  test "fundraising loans still lend and basket normally", %{lender: lender} do
    loan = loan_fixture().loan

    assert {:ok, _} =
             Commands.execute("add_loan_to_basket", lender, %{"loan_id" => to_string(loan.id)})

    assert {:ok, _} =
             Commands.execute("complete_demo_lend", lender, %{
               "loan_id" => to_string(loan.id),
               "amount_cents" => "2500"
             })
  end

  test "checkout lends fundraising items but keeps + reports items whose loan left fundraising",
       %{lender: lender} do
    live_loan = loan_fixture().loan
    stale_loan = loan_fixture(%{status: "repaying"}).loan

    # Both were added while (nominally) fundraising; stale_loan's status changed after.
    Basket.add(lender.id, live_loan.id, 2500)
    Basket.add(lender.id, stale_loan.id, 2500)

    assert %{lent: [%{loan_id: live_id}], skipped: [%{loan_id: stale_id}]} =
             Basket.checkout(lender)

    assert live_id == live_loan.id
    assert stale_id == stale_loan.id

    # The lent item is recorded and removed; the stale item stays in the basket.
    assert Repo.aggregate(from(l in Lend, where: l.loan_id == ^live_loan.id), :count) == 1
    assert Repo.aggregate(from(l in Lend, where: l.loan_id == ^stale_loan.id), :count) == 0
    assert [%{loan_id: ^stale_id}] = Basket.raw_items(lender.id)
  end
end
