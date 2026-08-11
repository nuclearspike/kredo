defmodule Kiva.PartnerTrusteeTest do
  @moduledoc "A7 — admin partner/trustee review (suspend/reactivate)."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Trust, Commands, Accounts}

  test "admin can suspend and reactivate a partner" do
    base = partner_user_fixture()

    {:ok, admin} =
      Accounts.register_user(%{email: "pt-a@kredo.test", password: "password", role: "admin"})

    {:ok, _} =
      Commands.execute("set_partner_status", admin, %{
        "partner_id" => to_string(base.partner.id),
        "status" => "suspended"
      })

    assert Kiva.Repo.get!(Kiva.Partners.Partner, base.partner.id).status == "suspended"

    {:ok, _} =
      Commands.execute("set_partner_status", admin, %{
        "partner_id" => to_string(base.partner.id),
        "status" => "active"
      })

    assert Kiva.Repo.get!(Kiva.Partners.Partner, base.partner.id).status == "active"
  end

  test "set_partner_status is admin-only" do
    base = partner_user_fixture()

    {:ok, staff} =
      Accounts.register_user(%{email: "pt-s@kredo.test", password: "password", role: "staff"})

    assert {:error, {:forbidden, "set_partner_status", "staff"}} =
             Commands.execute("set_partner_status", staff, %{
               "partner_id" => to_string(base.partner.id),
               "status" => "suspended"
             })
  end

  test "list_trustees surfaces status and set_trustee_status flips it" do
    trustee =
      Kiva.Repo.insert!(%Kiva.Trust.Trustee{
        slug: "acme-trust",
        country_code: "KE",
        status: "active"
      })

    {:ok, admin} =
      Accounts.register_user(%{email: "pt-ta@kredo.test", password: "password", role: "admin"})

    assert Enum.any?(
             Trust.list_trustees("en"),
             &(&1.trustee.id == trustee.id and &1.status == "active")
           )

    {:ok, _} =
      Commands.execute("set_trustee_status", admin, %{
        "trustee_id" => to_string(trustee.id),
        "status" => "suspended"
      })

    assert Enum.find(Trust.list_trustees("en"), &(&1.trustee.id == trustee.id)).status ==
             "suspended"
  end
end
