defmodule Kiva.LendAmountTest do
  # Regression tests for the "$25 increment" lending invariant: every lending
  # amount (lend, basket item) and every loan amount (requested, funded) must be
  # a positive multiple of 2500 cents, so aggregates like the browse hero's
  # "raised" stat can never show fractional dollars or non-$25 totals.
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Accounts, Basket, Commands, Repo}
  alias Kiva.Basket.Item
  alias Kiva.Lending.Loan
  alias Kiva.Portfolio.Lend

  setup do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{
        email: "amt-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    %{loan: loan, lender: lender}
  end

  describe "changeset invariants" do
    test "Lend.changeset rejects amounts that are not positive $25 multiples", %{
      loan: loan,
      lender: lender
    } do
      for bad <- [2137, 100, 9099, 2600, 0, -2500] do
        cs = Lend.changeset(%Lend{}, %{user_id: lender.id, loan_id: loan.id, amount_cents: bad})
        refute cs.valid?, "expected amount_cents=#{bad} to be rejected"
      end

      for good <- [2500, 5000, 25_000] do
        cs = Lend.changeset(%Lend{}, %{user_id: lender.id, loan_id: loan.id, amount_cents: good})
        assert cs.valid?, "expected amount_cents=#{good} to be accepted"
      end
    end

    test "Basket.Item.changeset rejects amounts that are not positive $25 multiples", %{
      loan: loan,
      lender: lender
    } do
      cs = Item.changeset(%Item{}, %{user_id: lender.id, loan_id: loan.id, amount_cents: 1337})
      refute cs.valid?

      cs = Item.changeset(%Item{}, %{user_id: lender.id, loan_id: loan.id, amount_cents: 7500})
      assert cs.valid?
    end

    test "Loan.changeset rejects loan/funded amounts that are not $25 multiples" do
      refute Loan.changeset(%Loan{}, %{slug: "amt-a", loan_amount_cents: 95_300}).valid?
      refute Loan.changeset(%Loan{}, %{slug: "amt-b", funded_amount_cents: 9_099}).valid?
      # 0 stays legal: drafts start at 0 requested / 0 funded.
      assert Loan.changeset(%Loan{}, %{
               slug: "amt-c",
               loan_amount_cents: 0,
               funded_amount_cents: 0
             }).valid?

      assert Loan.changeset(%Loan{}, %{
               slug: "amt-d",
               loan_amount_cents: 250_000,
               funded_amount_cents: 42_500
             }).valid?
    end
  end

  describe "command gate" do
    test "add_loan_to_basket rejects a non-$25-multiple amount", %{loan: loan, lender: lender} do
      assert {:error, _} =
               Commands.execute("add_loan_to_basket", lender, %{
                 "loan_id" => to_string(loan.id),
                 "amount_cents" => "2137"
               })

      assert Basket.total_cents(lender.id) == 0
    end

    test "complete_demo_lend rejects a non-$25-multiple amount and funds nothing", %{
      loan: loan,
      lender: lender
    } do
      before = Repo.get(Loan, loan.id).funded_amount_cents

      assert {:error, _} =
               Commands.execute("complete_demo_lend", lender, %{
                 "loan_id" => to_string(loan.id),
                 "amount_cents" => "2137"
               })

      assert Repo.get(Loan, loan.id).funded_amount_cents == before
      assert Repo.aggregate(Lend, :count) == 0
    end

    test "preview rejects invalid amounts too, so chat surfaces fail early", %{
      loan: loan,
      lender: lender
    } do
      assert {:error, _} =
               Commands.preview("complete_demo_lend", lender, %{
                 "loan_id" => to_string(loan.id),
                 "amount_cents" => 3700
               })
    end

    test "valid $25 multiples still lend end-to-end", %{loan: loan, lender: lender} do
      assert {:ok, _} =
               Commands.execute("complete_demo_lend", lender, %{
                 "loan_id" => to_string(loan.id),
                 "amount_cents" => "7500"
               })

      assert Repo.get(Loan, loan.id).funded_amount_cents == loan.funded_amount_cents + 7500
    end
  end

  describe "database tripwire" do
    test "raw inserts that bypass changesets are refused by the check constraint", %{
      loan: loan,
      lender: lender
    } do
      assert_raise Postgrex.Error, fn ->
        Repo.insert_all("lendings", [
          %{
            user_id: lender.id,
            loan_id: loan.id,
            amount_cents: 2137,
            inserted_at: DateTime.utc_now(:second)
          }
        ])
      end
    end
  end
end
