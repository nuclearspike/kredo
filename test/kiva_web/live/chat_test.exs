defmodule KivaWeb.ChatTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures

  setup do
    loan_fixture()
    :ok
  end

  # The assistant is now a sticky child LiveView (rendered in the root layout so it
  # persists across navigation), so it's exercised in isolation rather than through a page.
  test "open chat and ask for help", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, KivaWeb.ChatLive)
    view |> element("#kiva-chat-root button") |> render_click()

    html =
      view |> form("#kiva-chat-root form") |> render_submit(%{"message" => "what can you do?"})

    assert html =~ "assistant"
  end

  test "command mode proposes and confirms a language switch (anonymous → session redirect)", %{
    conn: conn
  } do
    {:ok, view, _html} = live_isolated(conn, KivaWeb.ChatLive)
    view |> element("#kiva-chat-root button") |> render_click()

    html =
      view |> form("#kiva-chat-root form") |> render_submit(%{"message" => "switch to spanish"})

    assert html =~ "Español"

    assert {:error, {:redirect, %{to: "/locale/es"}}} =
             view
             |> element("#kiva-chat-root button[phx-click='confirm_command']")
             |> render_click()
  end
end
