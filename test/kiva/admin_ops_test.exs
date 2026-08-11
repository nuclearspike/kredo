defmodule Kiva.AdminOpsTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Lending, Translation, Commands, LoanApplications}

  setup do
    submitted_loan_fixture()
  end

  test "a submitted loan appears in the review queue and generated translation jobs", %{
    draft: draft
  } do
    assert Enum.any?(Lending.review_queue("en"), &(&1.loan.id == draft.id))
    assert Enum.any?(Translation.list_review_queue(), &(&1.entity_type == "loan"))
  end

  test "staff can approve the listing (-> fundraising)", %{staff: staff, draft: draft} do
    assert {:ok, %{status: "fundraising"}} =
             Commands.execute("approve_loan_listing", staff, %{"loan_id" => to_string(draft.id)})
  end

  test "approve_loan_listing is blocked for a not-yet-submitted loan", %{
    staff: staff,
    partner: partner,
    user: user
  } do
    d2 = LoanApplications.create_or_resume_draft(partner.id, nil)

    Commands.execute("save_loan_draft", user, %{
      "loan_draft_id" => d2.id,
      "title" => "x",
      "risk_summary_public" => "low"
    })

    assert {:error, {:ineligible, "partner_review_complete", _}} =
             Commands.execute("approve_loan_listing", staff, %{"loan_id" => to_string(d2.id)})
  end

  test "approving a translation removes it from the queue", %{staff: staff} do
    [row | _] = Translation.list_review_queue()

    {:ok, _} =
      Commands.execute("approve_translation", staff, %{
        "lc_entity_type" => row.entity_type,
        "lc_id" => to_string(row.lc_id)
      })

    refute Enum.any?(
             Translation.list_review_queue(),
             &(&1.lc_id == row.lc_id and &1.entity_type == row.entity_type)
           )
  end
end
