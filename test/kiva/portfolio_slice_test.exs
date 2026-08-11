defmodule Kiva.PortfolioSliceTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Accounts, Lending, Portfolio}

  # Fixture schedules: 8 monthly items of 12_500¢ starting 2026-07-01. With the
  # loan fully funded at 100_000¢ and a 10_000¢ lend, the lender's share is
  # 1_250¢ per installment — 10_000¢ across the whole schedule.
  #
  # Lending is only allowed while fundraising, so this lends first and then
  # advances the loan to its target lifecycle status (as repayments would).
  defp lend_into(user, attrs \\ %{}, amounts) do
    target_status = Map.get(attrs, :status, "repaying")

    fx =
      loan_fixture(
        attrs
        |> Map.delete(:status)
        |> Map.put_new(:funded_amount_cents, 100_000)
      )

    Enum.each(List.wrap(amounts), &Portfolio.lend(user, fx.loan.id, &1))
    loan = fx.loan |> Ecto.Changeset.change(status: target_status) |> Repo.update!()
    %{fx | loan: loan}
  end

  defp lender do
    {:ok, user} =
      Accounts.register_user(%{
        email: "slice-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    user
  end

  describe "expected_repayment_series/2" do
    test "buckets the lender's share by due month, splitting scheduled vs received" do
      user = lender()
      %{loan: loan} = lend_into(user, [10_000])
      Lending.record_repayment(loan.id)

      series = Portfolio.expected_repayment_series(user.id)

      assert length(series) == 8
      assert %{month: ~D[2026-07-01], scheduled_cents: 1250, received_cents: 1250} = hd(series)
      assert Enum.all?(tl(series), &(&1.received_cents == 0))
      assert Enum.sum(Enum.map(series, & &1.scheduled_cents)) == 10_000
    end

    test "two lends to the same loan double the share; non-active statuses are excluded" do
      user = lender()
      lend_into(user, %{funded_amount_cents: 80_000}, [10_000, 10_000])
      lend_into(user, %{status: "completed"}, [2_500])
      %{loan: fundraising} = loan_fixture()
      Portfolio.lend(user, fundraising.id, 2_500)

      series = Portfolio.expected_repayment_series(user.id)

      # Only the repaying loan contributes; both its lends count.
      assert length(series) == 8
      assert hd(series).scheduled_cents == 2500
    end

    test "delinquent loans are included and dimension filters narrow the set" do
      user = lender()
      lend_into(user, [10_000])
      lend_into(user, %{country_code: "KE", status: "delinquent"}, [10_000])

      all = Portfolio.expected_repayment_series(user.id)
      only_ke = Portfolio.expected_repayment_series(user.id, %{country: "KE"})

      assert hd(all).scheduled_cents == 2500
      assert hd(only_ke).scheduled_cents == 1250
      assert Portfolio.expected_repayment_series(user.id, %{country: "US"}) == []
    end
  end

  describe "late_and_upcoming/2" do
    test "splits unpaid share into overdue (< today) and due within 30 days" do
      # No clock control here, so expectations are derived from the schedule's
      # actual due dates relative to the real today.
      user = lender()
      %{loan: loan} = lend_into(user, [10_000])
      today = Date.utc_today()

      dues =
        Repo.all(
          from(i in Kiva.Lending.RepaymentScheduleItem,
            join: rs in Kiva.Lending.RepaymentSchedule,
            on: rs.id == i.repayment_schedule_id,
            where: rs.loan_id == ^loan.id,
            select: i.due_on
          )
        )

      overdue = Enum.count(dues, &(Date.compare(&1, today) == :lt))

      upcoming =
        Enum.count(dues, &(Date.compare(&1, today) != :lt and Date.diff(&1, today) <= 30))

      flow = Portfolio.late_and_upcoming(user.id)
      assert flow.overdue_cents == overdue * 1250
      assert flow.upcoming_30_cents == upcoming * 1250

      # Paying the earliest installment moves its share out of whichever
      # bucket it sat in (or neither, when it lies beyond the 30-day window).
      earliest = Enum.min(dues, Date)
      Lending.record_repayment(loan.id)
      flow2 = Portfolio.late_and_upcoming(user.id)

      cond do
        Date.compare(earliest, today) == :lt ->
          assert flow2.overdue_cents == (overdue - 1) * 1250

        Date.diff(earliest, today) <= 30 ->
          assert flow2.upcoming_30_cents == (upcoming - 1) * 1250

        true ->
          assert flow2 == flow
      end
    end
  end

  describe "filters, groups and totals" do
    setup do
      user = lender()
      %{loan: gt, partner: partner} = lend_into(user, [10_000])
      %{loan: ke} = lend_into(user, %{country_code: "KE", partner_id: nil}, [5_000])
      %{user: user, gt: gt, ke: ke, partner: partner}
    end

    test "filtered_totals applies AND-ed dimension filters", %{user: user} do
      assert %{count: 2, total_cents: 15_000} = Portfolio.filtered_totals(user.id)

      assert %{count: 1, total_cents: 5_000} =
               Portfolio.filtered_totals(user.id, %{country: "KE"})

      assert %{count: 1, total_cents: 5_000} =
               Portfolio.filtered_totals(user.id, %{partner_id: :direct})

      assert %{count: 0, total_cents: 0} =
               Portfolio.filtered_totals(user.id, %{country: "GT", partner_id: :direct})
    end

    test "impact_groups keeps a stable :direct group for partnerless loans", %{user: user} do
      groups = Portfolio.impact_groups(user.id, "en", "partner")

      assert [
               %{key: _p, label: "Loom Co", lent_cents: 10_000},
               %{key: :direct, lent_cents: 5_000}
             ] =
               Enum.sort_by(groups, &(-&1.lent_cents))
    end

    test "impact_groups by country respects filters", %{user: user} do
      assert [%{key: "KE", count: 1}] =
               Portfolio.impact_groups(user.id, "en", "country", %{country: "KE"})
    end

    test "impact_loans honours filters with keyset pagination intact", %{user: user, ke: ke} do
      rows = Portfolio.impact_loans(user.id, "en", nil, 10, %{country: "KE"})
      assert [row] = rows
      assert row.slug == ke.slug
      assert Portfolio.impact_loans(user.id, "en", nil, 10, %{sector_id: -1}) == []
    end
  end
end
