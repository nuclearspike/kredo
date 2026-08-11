defmodule Kiva.LoanApplicationsTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{LoanApplications, Commands}
  alias Kiva.Localization.TranslationRequest

  setup do
    partner_user_fixture()
  end

  test "create_or_resume_draft pre-seeds from the borrower and resumes an open draft",
       %{partner: partner, borrower: borrower} do
    d1 = LoanApplications.create_or_resume_draft(partner.id, borrower.id)
    assert d1.status == "draft"
    assert d1.sector_id == borrower.sector_id

    d2 = LoanApplications.create_or_resume_draft(partner.id, borrower.id)
    assert d2.id == d1.id
  end

  test "reuse_suggestions surfaces prior loan terms", %{borrower: borrower} do
    s = LoanApplications.reuse_suggestions(borrower)
    assert s.sector_id == borrower.sector_id
    assert s.prior_amount_cents == 100_000
    assert s.prior_term_months == 8
  end

  test "submit is gated by draft_complete eligibility, then succeeds and queues translations",
       %{user: user, partner: partner, borrower: borrower, sector: sector} do
    draft = LoanApplications.create_or_resume_draft(partner.id, borrower.id)
    refute LoanApplications.draft_complete?(draft.id)

    assert {:error, {:ineligible, "draft_complete", _}} =
             Commands.execute("submit_loan_for_review", user, %{"loan_draft_id" => draft.id})

    {:ok, _} =
      Commands.execute("save_loan_draft", user, %{
        "loan_draft_id" => draft.id,
        "amount" => "500",
        "term" => "8",
        "sector_id" => to_string(sector.id),
        "title" => "A new weaving loan",
        "borrower_story" => "Rosa needs more thread",
        "loan_use" => "Buy thread"
      })

    assert LoanApplications.draft_complete?(draft.id)

    assert {:ok, %{status: "submitted_to_staff"}} =
             Commands.execute("submit_loan_for_review", user, %{"loan_draft_id" => draft.id})

    # one translation request per non-source locale (5 supported - en)
    assert Repo.aggregate(from(r in TranslationRequest, where: r.entity_type == "loan"), :count) ==
             4
  end

  test "a partner cannot submit another partner's draft", %{user: user} do
    other = partner_user_fixture()
    draft = LoanApplications.create_or_resume_draft(other.partner.id, other.borrower.id)

    assert {:error, {:ineligible, "partner_owns_draft", _}} =
             Commands.execute("save_loan_draft", user, %{
               "loan_draft_id" => draft.id,
               "title" => "hijack"
             })
  end
end
