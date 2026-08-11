defmodule KivaWeb.AdminLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures

  setup do
    submitted_loan_fixture()
  end

  test "the analytics dashboard renders for staff", %{conn: conn, staff: staff} do
    conn = log_in(conn, staff)
    {:ok, _view, html} = live(conn, ~p"/admin")
    assert html =~ "Distribution analytics"
    assert html =~ "Loans by status"
    assert html =~ "Funding raised by sector"
  end

  test "an admin can advance the demo time machine", %{conn: conn} do
    Kiva.LendingFixtures.loan_fixture()

    {:ok, admin} =
      Kiva.Accounts.register_user(%{
        email: "adm-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "admin"
      })

    conn = log_in(conn, admin)
    {:ok, view, _} = live(conn, ~p"/admin")
    html = view |> element("button[phx-click='advance_time']") |> render_click()
    assert html =~ "Advanced the demo"
  end

  test "an admin can suspend a partner from the dashboard", %{conn: conn} do
    base = Kiva.LendingFixtures.partner_user_fixture()

    {:ok, admin} =
      Kiva.Accounts.register_user(%{
        email: "pta-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "admin"
      })

    conn = log_in(conn, admin)
    {:ok, view, html} = live(conn, ~p"/admin")
    assert html =~ "Partners &amp; trustees"

    html =
      view
      |> element("button[phx-value-id='#{base.partner.id}'][phx-click='set_partner_status']")
      |> render_click()

    assert html =~ "Partner status updated"
  end

  test "staff can moderate a held encouragement message", %{conn: conn, staff: staff} do
    loan = Kiva.LendingFixtures.loan_fixture().loan

    {:ok, lender} =
      Kiva.Accounts.register_user(%{
        email: "mod-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    Kiva.Messaging.create_encouragement(lender, loan.id, "you scam loser", "en")

    conn = log_in(conn, staff)
    {:ok, view, html} = live(conn, ~p"/admin")
    assert html =~ "Encouragement moderation"
    assert html =~ "you scam loser"
    html = view |> element("button[phx-click='approve_message']") |> render_click()
    assert html =~ "approved and delivered"
  end

  test "the review queue is expandable and the AI/audit panels are present", %{
    conn: conn,
    staff: staff
  } do
    conn = log_in(conn, staff)
    {:ok, _view, html} = live(conn, ~p"/admin")
    assert html =~ "Review details"
    assert html =~ "AI tool calls"
    assert html =~ "Filter by event type"
  end

  test "staff can inspect an AI conversation from a tool call", %{conn: conn, staff: staff} do
    conv = Kiva.AI.start_conversation(%{actor_role: "lender", locale_code: "en"})
    Kiva.AI.add_message(conv.id, "user", "How do I lend?")

    Kiva.AI.record_tool_call(conv.id, %{
      tool_type: "graphql",
      schema_surface: "LenderGraphQL",
      operation_name: "lend",
      allowed: true
    })

    conn = log_in(conn, staff)
    {:ok, view, _} = live(conn, ~p"/admin")
    html = view |> element("button[phx-click='inspect_ai']") |> render_click()
    assert html =~ "How do I lend?"
  end

  test "staff sees the review and translation queues", %{conn: conn, staff: staff} do
    conn = log_in(conn, staff)
    {:ok, _view, html} = live(conn, ~p"/admin")
    assert html =~ "Loan review queue"
    assert html =~ "Submit me"
    assert html =~ "Translation review queue"
  end

  test "staff can approve a translation from the queue", %{conn: conn, staff: staff} do
    conn = log_in(conn, staff)
    {:ok, view, _} = live(conn, ~p"/admin")
    [row | _] = Kiva.Translation.list_review_queue()

    html =
      view
      |> element(
        "button[phx-click='approve_tx'][phx-value-id='#{row.lc_id}'][phx-value-type='#{row.entity_type}']"
      )
      |> render_click()

    assert html =~ "Translation approved"
  end

  test "staff can approve a loan listing", %{conn: conn, staff: staff} do
    conn = log_in(conn, staff)
    {:ok, view, _} = live(conn, ~p"/admin")
    html = view |> element("button[phx-click='approve_loan']") |> render_click()
    assert html =~ "approved and published" or html =~ "No loans awaiting review"
  end
end
