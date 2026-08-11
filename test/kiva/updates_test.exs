defmodule Kiva.UpdatesTest do
  @moduledoc "P4/P9 — borrower updates + closing outcomes, revealed to lenders."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Updates, Portfolio, Notifications, Commands, Accounts}

  setup do
    base = partner_user_fixture()

    {:ok, lender} =
      Accounts.register_user(%{email: "ul@kredo.test", password: "password", role: "lender"})

    Portfolio.lend(lender, base.loan.id, 2500)
    Map.put(base, :lender, lender)
  end

  test "posting an update reveals to the loan's lenders", %{
    user: partner,
    loan: loan,
    lender: lender
  } do
    Updates.post_update(partner, loan.id, "update", "Rosa finished the order", "en")
    [u] = Updates.list_for_loan(loan.id, "en")
    assert u.body == "Rosa finished the order"
    assert Enum.any?(Notifications.list_for_user(lender.id), &(&1.type == "borrower_update"))
  end

  test "an outcome reveals as a completion story", %{user: partner, loan: loan, lender: lender} do
    Updates.post_update(partner, loan.id, "outcome", "Order shipped; Rosa is hiring", "en")
    assert Enum.any?(Notifications.list_for_user(lender.id), &(&1.type == "loan_outcome"))
    assert [%{kind: "outcome"}] = Updates.list_for_loan(loan.id, "en")
  end

  test "post_borrower_update runs through the registry (partner/staff only)", %{
    user: partner,
    loan: loan
  } do
    assert {:ok, %{target_type: "loan"}} =
             Commands.execute("post_borrower_update", partner, %{
               "loan_id" => to_string(loan.id),
               "body" => "Progress",
               "source_locale_code" => "en"
             })

    {:ok, lender2} =
      Accounts.register_user(%{email: "ul2@kredo.test", password: "password", role: "lender"})

    assert {:error, {:forbidden, "post_borrower_update", "lender"}} =
             Commands.execute("post_borrower_update", lender2, %{
               "loan_id" => to_string(loan.id),
               "body" => "x",
               "source_locale_code" => "en"
             })
  end

  test "on-demand translation of an update", %{user: partner, loan: loan} do
    Updates.post_update(partner, loan.id, "update", "Great progress", "en")
    [de] = Updates.list_for_loan(loan.id, "de")
    assert de.fallback_used

    {:ok, _} = Updates.ensure_translation(de.update.id, "de")
    [de2] = Updates.list_for_loan(loan.id, "de")
    refute de2.fallback_used
    assert de2.body =~ "[de←en]"
  end
end
