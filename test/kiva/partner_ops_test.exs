defmodule Kiva.PartnerOpsTest do
  @moduledoc "P5/P7/P8 — disbursal reveal + partner dashboard/repayments-due."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Lending, Notifications, Commands, Portfolio, Accounts}

  test "record_disbursal advances status, stamps disbursed_at, reveals to lenders" do
    base = partner_user_fixture()

    {:ok, lender} =
      Accounts.register_user(%{email: "do@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, base.loan.id, 2500)

    loan = Lending.record_disbursal(base.loan.id)
    assert loan.disbursed_at
    assert loan.disbursal_status in ["post_disbursed", "direct_disbursed"]
    assert Enum.any?(Notifications.list_for_user(lender.id), &(&1.type == "disbursal"))
  end

  test "record_disbursal runs through the registry (partner/staff)" do
    base = partner_user_fixture()

    assert {:ok, %{target_type: "loan"}} =
             Commands.execute("record_disbursal", base.user, %{
               "loan_id" => to_string(base.loan.id)
             })
  end

  test "partner_overview aggregates loans; repayments due is a paged, searchable list" do
    base = partner_user_fixture()

    # Repayments are only due once the loan is past fundraising.
    base.loan |> Ecto.Changeset.change(status: "repaying") |> Kiva.Repo.update!()

    o = Lending.partner_overview(base.partner.id)
    assert o.count >= 1
    assert o.total_funded_cents > 0
    assert o.repayments_due_count >= 1

    %{rows: rows, total: total} = Lending.partner_repayments_due(base.partner.id)
    assert total >= 1
    assert Enum.any?(rows, &(&1.loan.id == base.loan.id))

    # search by the borrower's name (fixture borrower is "Rosa")
    %{rows: found} = Lending.partner_repayments_due(base.partner.id, %{q: "Rosa"})
    assert Enum.any?(found, &(&1.loan.id == base.loan.id))
    assert Lending.partner_repayments_due(base.partner.id, %{q: "zzznope"}).rows == []
  end

  test "repayments due paginate" do
    base = partner_user_fixture()
    base.loan |> Ecto.Changeset.change(status: "repaying") |> Kiva.Repo.update!()

    loan2 =
      Lending.upsert_loan(%{
        slug: "due2-#{System.unique_integer([:positive])}",
        status: "funded",
        partner_id: base.partner.id,
        borrower_id: base.borrower.id,
        country_code: "GT",
        sector_id: base.sector.id,
        trust_model: "partner_facilitated",
        disbursal_status: "pre_disbursed",
        loan_amount_cents: 100_000,
        funded_amount_cents: 100_000,
        currency_code: "USD",
        repayment_term_months: 8,
        source_locale_code: "en"
      })

    Lending.create_repayment_schedule(loan2.id, ~D[2026-09-01], 8, 12_500)

    p1 = Lending.partner_repayments_due(base.partner.id, %{per_page: 1, page: 1})
    assert p1.total == 2
    assert p1.pages == 2
    assert [%{loan: %{id: id1}}] = p1.rows

    p2 = Lending.partner_repayments_due(base.partner.id, %{per_page: 1, page: 2})
    assert [%{loan: %{id: id2}}] = p2.rows
    refute id1 == id2
  end
end
