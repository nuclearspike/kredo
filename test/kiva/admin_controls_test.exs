defmodule Kiva.AdminControlsTest do
  @moduledoc "A1/A2 — demo time machine + actionable permission outliers."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Lending, Permissions, Commands, Accounts, Notifications, Portfolio, Repo}
  alias Kiva.Lending.Loan
  alias Kiva.Accounts.Permission

  test "advance_demo_time walks a loan fund -> disburse -> repay, revealing to lenders" do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "atl@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, loan.id, 2500)

    Lending.advance_demo_time()
    l1 = Repo.get!(Loan, loan.id)
    assert l1.status == "funded"
    assert l1.funded_amount_cents == l1.loan_amount_cents
    assert Enum.any?(Notifications.list_for_user(lender.id), &(&1.type == "loan_funded"))

    Lending.advance_demo_time()
    assert Repo.get!(Loan, loan.id).disbursed_at

    Lending.advance_demo_time()
    assert Enum.any?(Notifications.list_for_user(lender.id), &(&1.type == "repayment"))
  end

  test "advance_demo_time runs through the registry (admin only)" do
    {:ok, admin} =
      Accounts.register_user(%{email: "ata@kredo.test", password: "password", role: "admin"})

    assert {:ok, %{target_type: "system"}} = Commands.execute("advance_demo_time", admin, %{})

    {:ok, staff} =
      Accounts.register_user(%{email: "ats@kredo.test", password: "password", role: "staff"})

    assert {:error, {:forbidden, "advance_demo_time", "staff"}} =
             Commands.execute("advance_demo_time", staff, %{})
  end

  test "revoke_permission clears a direct-grant outlier" do
    Repo.insert!(%Permission{key: "approve_loan_listing", label: "x", risk_level: "high"})

    {:ok, lender} =
      Accounts.register_user(%{email: "arl@kredo.test", password: "password", role: "lender"})

    {:ok, admin} =
      Accounts.register_user(%{email: "ara@kredo.test", password: "password", role: "admin"})

    Permissions.grant_direct(lender.id, "approve_loan_listing", admin.id, "demo")
    assert length(Permissions.list_outliers()) == 1

    {:ok, _} =
      Commands.execute("revoke_permission", admin, %{
        "user_id" => to_string(lender.id),
        "permission_key" => "approve_loan_listing"
      })

    assert Permissions.list_outliers() == []
  end
end
