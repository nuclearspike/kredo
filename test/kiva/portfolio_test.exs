defmodule Kiva.PortfolioTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Portfolio, Accounts, Commands, Repo}
  alias Kiva.Lending.Loan

  setup do
    {:ok, lender} =
      Accounts.register_user(%{email: "p@kredo.test", password: "password", role: "lender"})

    %{lender: lender, loan: loan_fixture().loan}
  end

  test "lending advances loan funding and records a lending", %{lender: lender, loan: loan} do
    before = loan.funded_amount_cents
    Portfolio.lend(lender, loan.id, 2500)
    assert Repo.get(Loan, loan.id).funded_amount_cents == before + 2500

    summary = Portfolio.portfolio_summary(lender.id)
    assert summary.count == 1
    assert summary.total_cents == 2500
  end

  test "the repayment projection never pays a lender more than they lent" do
    # Lenders earn 0%: the most that can come back is the principal. A borrower's
    # schedule may still total more than the loan (the fixture's totals 100_000 on
    # 25_000 of principal) because the field partner charges the borrower interest
    # — that overage stays with the partner and must not reach the lender's chart.
    %{loan: loan} =
      loan_fixture(%{
        loan_amount_cents: 25_000,
        funded_amount_cents: 25_000,
        status: "repaying"
      })

    {:ok, lender} =
      Accounts.register_user(%{
        email: "cap-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    Repo.insert!(%Kiva.Portfolio.Lend{
      user_id: lender.id,
      loan_id: loan.id,
      amount_cents: 25_000
    })

    projected =
      lender.id
      |> Portfolio.expected_repayment_series()
      |> Enum.map(& &1.scheduled_cents)
      |> Enum.sum()

    assert projected == 25_000

    flow = Portfolio.late_and_upcoming(lender.id)
    assert flow.overdue_cents + flow.upcoming_30_cents <= 25_000
  end

  test "complete_demo_lend command path works and audits", %{lender: lender, loan: loan} do
    assert {:ok, %{target_type: "loan"}} =
             Commands.execute("complete_demo_lend", lender, %{
               "loan_id" => to_string(loan.id),
               "amount_cents" => "2500"
             })

    assert Enum.any?(Kiva.Audit.list_events(), &(&1.event_type == "loan.lent"))
  end
end
