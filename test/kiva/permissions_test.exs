defmodule Kiva.PermissionsTest do
  use Kiva.DataCase, async: true

  alias Kiva.{Permissions, Accounts}
  alias Kiva.Accounts.Permission

  test "grant_direct records a permission outlier" do
    Repo.insert!(%Permission{key: "approve_loan_listing", label: "Approve", risk_level: "high"})

    {:ok, lender} =
      Accounts.register_user(%{
        email: "o-lender@kredo.test",
        password: "password",
        role: "lender"
      })

    {:ok, admin} =
      Accounts.register_user(%{email: "o-admin@kredo.test", password: "password", role: "admin"})

    Permissions.grant_direct(lender.id, "approve_loan_listing", admin.id, "demo")

    outliers = Permissions.list_outliers()

    assert [%{email: "o-lender@kredo.test", permission: "approve_loan_listing", risk: "high"}] =
             outliers
  end
end
