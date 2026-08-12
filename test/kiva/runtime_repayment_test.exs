defmodule Kiva.RuntimeRepaymentTest do
  @moduledoc """
  A loan that lives its whole life at runtime must be able to repay.

  Every seeded loan is handed a repayment schedule at seed time, so the demo
  data hides whether disbursal produces one. These tests use a loan that has
  never been given a schedule.
  """
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Lending, Portfolio, Accounts, Repo}
  alias Kiva.Lending.Loan

  defp unscheduled_funded_loan do
    base = loan_fixture(%{funded_amount_cents: 100_000, status: "funded"}, schedule: false)
    refute Repo.preload(base.loan, :repayment_schedule).repayment_schedule
    base
  end

  defp reload(loan_id), do: Repo.get!(Loan, loan_id) |> Repo.preload(repayment_schedule: :items)

  test "disbursal gives the loan a repayment schedule" do
    base = unscheduled_funded_loan()

    Lending.record_disbursal(base.loan.id)
    loan = reload(base.loan.id)

    assert loan.repayment_schedule, "a disbursed loan must have a repayment schedule"
    assert length(loan.repayment_schedule.items) == loan.repayment_term_months
  end

  test "the scheduled items total the principal exactly" do
    # Loan amounts are always multiples of $25, so the remainder comes from the
    # term: 100_000 over 8 divides evenly, over 7 or 12 it does not, and those
    # leftover cents must land in the schedule rather than vanish into div/2.
    for {amount, term} <- [{100_000, 8}, {100_000, 7}, {100_000, 12}, {102_500, 9}] do
      base =
        loan_fixture(
          %{
            loan_amount_cents: amount,
            funded_amount_cents: amount,
            status: "funded",
            repayment_term_months: term
          },
          schedule: false
        )

      Lending.record_disbursal(base.loan.id)
      items = reload(base.loan.id).repayment_schedule.items

      assert length(items) == term

      assert Enum.sum(Enum.map(items, & &1.amount_cents)) == amount,
             "#{amount} cents over #{term} months must schedule exactly #{amount}"
    end
  end

  test "a disbursed loan enters repayment and can actually be repaid" do
    base = unscheduled_funded_loan()

    Lending.record_disbursal(base.loan.id)
    assert reload(base.loan.id).status == "repaying"

    assert {:ok, _item} = Lending.record_repayment(base.loan.id)
  end

  test "advance_demo_time drives a runtime loan all the way to completed" do
    base = unscheduled_funded_loan()

    # Disbursal, then one repayment per tick for the loan's whole term.
    for _ <- 1..(base.loan.repayment_term_months + 2), do: Lending.advance_demo_time()

    assert reload(base.loan.id).status == "completed",
           "a loan disbursed at runtime must repay to completion, not stall"
  end

  test "a loan with no repayment term is not moved into repayment" do
    base =
      loan_fixture(
        %{funded_amount_cents: 100_000, status: "funded", repayment_term_months: nil},
        schedule: false
      )

    Lending.record_disbursal(base.loan.id)
    loan = reload(base.loan.id)

    refute loan.repayment_schedule

    assert loan.status == "funded",
           "claiming repaying without a schedule recreates the stall this fix exists to remove"

    assert loan.disbursed_at, "the disbursal itself still happened"
  end

  test "a loan disbursed while unscheduled is given one when funding completes" do
    # The state left behind by any loan disbursed before disbursal created
    # schedules: funds already out, no schedule, still fundraising.
    base =
      loan_fixture(
        %{
          status: "fundraising",
          loan_amount_cents: 100_000,
          funded_amount_cents: 75_000,
          disbursed_at: ~U[2026-07-01 00:00:00Z],
          disbursal_status: "direct_disbursed"
        },
        schedule: false
      )

    {:ok, lender} =
      Accounts.register_user(%{email: "late@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, base.loan.id, 25_000)
    loan = reload(base.loan.id)

    assert loan.repayment_schedule, "funding an already-disbursed loan must give it a schedule"
    assert loan.status == "repaying"
    assert Enum.sum(Enum.map(loan.repayment_schedule.items, & &1.amount_cents)) == 100_000
  end

  test "a completed loan is not walked backwards, nor given fresh obligations" do
    base = loan_fixture(%{funded_amount_cents: 100_000, status: "completed"}, schedule: false)

    Lending.record_disbursal(base.loan.id)
    loan = reload(base.loan.id)

    assert loan.status == "completed"

    refute loan.repayment_schedule,
           "a discharged loan must not be handed a new set of repayments to make"
  end

  test "disbursing twice does not re-stamp the loan or re-tell the lenders" do
    base =
      loan_fixture(
        %{
          status: "fundraising",
          loan_amount_cents: 100_000,
          funded_amount_cents: 0,
          disbursal_status: "direct_disbursal_pending"
        },
        schedule: false
      )

    {:ok, lender} =
      Accounts.register_user(%{email: "twice@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, base.loan.id, 2500)

    Lending.record_disbursal(base.loan.id)
    first = reload(base.loan.id)
    before = Kiva.Notifications.list_for_user(lender.id) |> length()

    Lending.record_disbursal(base.loan.id)
    second = reload(base.loan.id)

    assert second.disbursed_at == first.disbursed_at, "the disbursal date must not move"
    assert second.disbursal_status == first.disbursal_status

    assert length(Kiva.Notifications.list_for_user(lender.id)) == before,
           "lenders must not be told the money moved a second time"
  end

  test "the database refuses a loan a second repayment schedule" do
    base = unscheduled_funded_loan()
    Lending.record_disbursal(base.loan.id)

    assert_raise Ecto.ConstraintError, ~r/repayment_schedules_loan_id_index/, fn ->
      Lending.create_principal_repayment_schedule(base.loan.id, ~D[2026-07-01], 6, 60_000)
    end

    assert length(reload(base.loan.id).repayment_schedule.items) == 8,
           "the original schedule survives the rejected one"
  end

  test "a backfilled schedule is dated from the disbursal, not from today" do
    disbursed_on = ~U[2026-07-01 00:00:00Z]

    base =
      loan_fixture(
        %{
          status: "fundraising",
          loan_amount_cents: 100_000,
          funded_amount_cents: 75_000,
          disbursed_at: disbursed_on,
          disbursal_status: "direct_disbursed"
        },
        schedule: false
      )

    {:ok, lender} =
      Accounts.register_user(%{email: "dates@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, base.loan.id, 25_000)
    schedule = reload(base.loan.id).repayment_schedule

    assert schedule.starts_on == DateTime.to_date(disbursed_on),
           "repayments run from when the money went out"

    assert Enum.min(Enum.map(schedule.items, & &1.due_on), Date) ==
             Date.add(DateTime.to_date(disbursed_on), 30)
  end

  test "disbursing before the crowd finishes leaves the loan fundraising, then repaying" do
    base =
      loan_fixture(
        %{
          status: "fundraising",
          loan_amount_cents: 100_000,
          funded_amount_cents: 75_000,
          disbursal_status: "direct_disbursal_pending"
        },
        schedule: false
      )

    Lending.record_disbursal(base.loan.id)

    loan = reload(base.loan.id)

    assert loan.status == "fundraising",
           "a partner disbursing early must not close the loan to the remaining lenders"

    assert loan.repayment_schedule, "the schedule is owed from disbursal, not from funding"

    {:ok, lender} =
      Accounts.register_user(%{email: "early@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, base.loan.id, 25_000)

    assert reload(base.loan.id).status == "repaying",
           "the last dollar on an already-disbursed loan moves it into repayment"
  end
end
