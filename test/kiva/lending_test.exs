defmodule Kiva.LendingStageTest do
  # A fundraising loan has no repayments due yet — the partner overview must
  # not list it in `repayments_due`.
  use Kiva.DataCase, async: true
  import Kiva.LendingFixtures

  test "schedule items preload date-ordered regardless of physical row order" do
    base = loan_fixture(%{status: "repaying"})
    schedule = Kiva.Repo.preload(base.loan, :repayment_schedule).repayment_schedule

    Kiva.Repo.delete_all(
      from i in Kiva.Lending.RepaymentScheduleItem,
        where: i.repayment_schedule_id == ^schedule.id
    )

    for d <- [~D[2027-01-01], ~D[2026-06-01], ~D[2026-01-01]] do
      Kiva.Repo.insert!(%Kiva.Lending.RepaymentScheduleItem{
        repayment_schedule_id: schedule.id,
        due_on: d,
        amount_cents: 2500,
        status: "scheduled"
      })
    end

    profile = Kiva.Lending.get_localized_loan(base.loan.slug, "en")
    dates = Enum.map(profile.schedule.items, & &1.due_on)
    assert dates == Enum.sort(dates, Date)
  end

  test "repayments due exclude fundraising loans and surface funded ones" do
    base = loan_fixture()

    # Fundraising: nothing due yet.
    assert Kiva.Lending.partner_overview(base.partner.id).repayments_due_count == 0
    assert Kiva.Lending.partner_repayments_due(base.partner.id).rows == []

    base.loan |> Ecto.Changeset.change(status: "repaying") |> Kiva.Repo.update!()

    assert Kiva.Lending.partner_overview(base.partner.id).repayments_due_count == 1

    assert %{rows: [row], total: 1} = Kiva.Lending.partner_repayments_due(base.partner.id)
    assert row.loan.id == base.loan.id
  end
end

defmodule Kiva.LendingTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.Lending

  setup do
    %{loan: loan_fixture().loan}
  end

  test "localizes loan cards to es and falls back to en for de", %{loan: loan} do
    [es] = Lending.list_localized_loans("es", %{})
    assert es.title == "Préstamo de tejido"
    refute es.fallback_used

    [de] = Lending.list_localized_loans("de", %{})
    assert de.title == "Weaving loan"
    assert de.fallback_used
    assert de.resolved_locale == "en"
    assert de.sector_name == "Arts"
    _ = loan
  end

  test "funded_percent is computed from cents", %{loan: loan} do
    assert Lending.funded_percent(loan) == 40
  end

  test "filters by sector, country, trust model and text", %{loan: loan} do
    assert [_] = Lending.list_localized_loans("en", %{sector_id: loan.sector_id})
    assert [] = Lending.list_localized_loans("en", %{country_code: "KE"})
    assert [_] = Lending.list_localized_loans("en", %{trust_model: "partner_facilitated"})
    assert [_] = Lending.list_localized_loans("en", %{q: "weaving"})
    assert [] = Lending.list_localized_loans("en", %{q: "spaceship"})
  end

  test "get_localized_loan returns a profile with schedule", %{loan: loan} do
    profile = Lending.get_localized_loan(loan.slug, "en")
    assert profile.borrower_story == "Rosa weaves textiles"
    assert profile.schedule
    assert length(profile.schedule.items) == 8
  end
end
