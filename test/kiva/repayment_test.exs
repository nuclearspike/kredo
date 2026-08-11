defmodule Kiva.RepaymentTest do
  @moduledoc "Item 1 — closing the lending loop."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Lending, Portfolio, Commands, Accounts}
  alias Kiva.Lending.Loan

  setup do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "rl@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, loan.id, 2500)
    %{loan: loan, lender: lender}
  end

  test "record_repayment advances the schedule and credits lenders", %{loan: loan, lender: lender} do
    {:ok, item} = Lending.record_repayment(loan.id)
    assert item.status == "paid"

    profile = Lending.get_localized_loan(loan.slug, "en")
    assert profile.repayment.paid_count == 1
    assert profile.repayment.total_count == 8

    summary = Portfolio.portfolio_summary(lender.id)
    assert summary.returned_cents > 0
    assert summary.available_to_relend_cents == summary.returned_cents
  end

  test "a lender's return never exceeds what they lent", %{loan: loan, lender: lender} do
    for _ <- 1..8, do: Lending.record_repayment(loan.id)
    summary = Portfolio.portfolio_summary(lender.id)
    assert summary.returned_cents <= summary.total_cents
  end

  test "fully repaying completes the loan", %{loan: loan} do
    for _ <- 1..8, do: Lending.record_repayment(loan.id)
    assert {:error, :fully_repaid} = Lending.record_repayment(loan.id)
    assert Repo.get!(Loan, loan.id).status == "completed"
  end

  test "record_repayment runs through the command registry (partner/staff only)", %{loan: loan} do
    {:ok, partner} =
      Accounts.register_user(%{email: "rp@kredo.test", password: "password", role: "partner"})

    assert {:ok, %{target_type: "loan"}} =
             Commands.execute("record_repayment", partner, %{"loan_id" => to_string(loan.id)})

    {:ok, lender} =
      Accounts.register_user(%{email: "rl2@kredo.test", password: "password", role: "lender"})

    assert {:error, {:forbidden, "record_repayment", "lender"}} =
             Commands.execute("record_repayment", lender, %{"loan_id" => to_string(loan.id)})
  end
end
