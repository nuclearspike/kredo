defmodule KivaWeb.FaqLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiva.Content

  setup do
    {:ok, faq} =
      Content.create_faq(%{
        slug: "lend",
        category: "Basics",
        position: 0,
        source_locale_code: "en"
      })

    Content.upsert_faq_lc(%{
      faq_entry_id: faq.id,
      locale_code: "en",
      is_source: true,
      source_locale_code: "en",
      question: "How does lending work?",
      answer: "Lenders fund a borrower's loan.",
      translation_status: "published"
    })

    %{faq: faq}
  end

  test "shows the English source with a fallback badge when viewing in German", %{conn: conn} do
    conn = conn |> init_test_session(%{locale: "de"})
    {:ok, _view, html} = live(conn, ~p"/faq")
    assert html =~ "How does lending work?"
    assert html =~ "showing" or html =~ "EN"
  end

  test "on-demand translate creates a machine translation in the current locale", %{
    conn: conn,
    faq: faq
  } do
    conn = conn |> init_test_session(%{locale: "de"})
    {:ok, view, _html} = live(conn, ~p"/faq")

    html = view |> element("button[phx-value-id='#{faq.id}']") |> render_click()
    assert html =~ "[de←en]"

    # persisted as a machine row
    item = Content.list_localized_faqs("de") |> hd()
    assert item.status == "machine"
  end
end
