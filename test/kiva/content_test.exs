defmodule Kiva.ContentTest do
  use Kiva.DataCase, async: true

  alias Kiva.Content

  defp faq_fixture do
    {:ok, faq} =
      Content.create_faq(%{slug: "q1", category: "Basics", position: 0, source_locale_code: "en"})

    Content.upsert_faq_lc(%{
      faq_entry_id: faq.id,
      locale_code: "en",
      is_source: true,
      source_locale_code: "en",
      question: "How does a loan work?",
      answer: "A lender funds a borrower.",
      translation_status: "published"
    })

    faq
  end

  test "list_localized_faqs falls back to en and flags it" do
    faq_fixture()
    [item] = Content.list_localized_faqs("de")
    assert item.resolved_locale == "en"
    assert item.fallback_used
    assert item.lc.question == "How does a loan work?"
  end

  test "ensure_faq_translation creates a machine row and is idempotent" do
    faq = faq_fixture()

    {:ok, row} = Content.ensure_faq_translation(faq.id, "de")
    assert row.locale_code == "de"
    assert row.translation_status == "machine"
    assert row.translated_by_ai_model == "mock-mt-v0"
    assert row.question =~ "[de←en]"

    {:ok, row2} = Content.ensure_faq_translation(faq.id, "de")
    assert row2.id == row.id

    # now de resolves without fallback, badged as machine/unreviewed
    item = Content.list_localized_faqs("de") |> hd()
    refute item.fallback_used
    assert item.status == "machine"
  end

  test "approve_faq_translation promotes a machine row to approved" do
    {:ok, reviewer} =
      Kiva.Accounts.register_user(%{email: "r@kredo.test", password: "password", role: "staff"})

    faq = faq_fixture()
    {:ok, row} = Content.ensure_faq_translation(faq.id, "fr")
    {:ok, approved} = Content.approve_faq_translation(row, reviewer.id)
    assert approved.translation_status == "approved"
    assert approved.human_reviewer_user_id == reviewer.id
    assert approved.reviewed_at
  end
end
