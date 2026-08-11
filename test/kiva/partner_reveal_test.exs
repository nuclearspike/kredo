defmodule Kiva.PartnerRevealTest do
  @moduledoc "P2/P3 — changes-requested reason + partner reveals."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Notifications, Commands, Repo}
  alias Kiva.Lending.Loan

  setup do
    submitted_loan_fixture()
  end

  test "request_changes captures a reason and notifies the partner", %{
    staff: staff,
    draft: draft,
    user: partner_user
  } do
    {:ok, _} =
      Commands.execute("request_loan_changes", staff, %{
        "loan_id" => to_string(draft.id),
        "reason" => "Add a clearer photo"
      })

    loan = Repo.get!(Loan, draft.id)
    assert loan.status == "changes_requested"
    assert loan.changes_requested_reason == "Add a clearer photo"

    assert Enum.any?(
             Notifications.list_for_user(partner_user.id),
             &(&1.type == "changes_requested")
           )
  end

  test "approving a listing notifies the partner it is live", %{
    staff: staff,
    draft: draft,
    user: partner_user
  } do
    translate_fully(draft)

    {:ok, _} =
      Commands.execute("approve_loan_listing", staff, %{"loan_id" => to_string(draft.id)})

    assert Enum.any?(Notifications.list_for_user(partner_user.id), &(&1.type == "loan_approved"))
  end

  test "notify_partner is a no-op for a loan with no partner" do
    assert Notifications.notify_partner(%{partner_id: nil}, "x", "t", "b", nil) == 0
  end
end
