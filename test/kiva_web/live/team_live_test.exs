defmodule KivaWeb.TeamLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Kiva.{Teams, Accounts}

  setup do
    {:ok, lender} =
      Accounts.register_user(%{email: "tl@kredo.test", password: "password", role: "lender"})

    team =
      Teams.create_team(lender, %{
        "name" => "Existing Team",
        "source_locale_code" => "en",
        "visibility" => "public"
      })

    %{lender: lender, team: team}
  end

  test "teams index lists teams", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/teams")
    assert html =~ "Existing Team"
  end

  test "a lender can create a team and is navigated to it", %{conn: conn, lender: lender} do
    conn = log_in(conn, lender)
    {:ok, view, _html} = live(conn, ~p"/teams")

    assert {:error, {:live_redirect, %{to: "/teams/" <> _}}} =
             view
             |> form("form[phx-submit='create_team']",
               team: %{name: "My New Team", source_locale_code: "en", visibility: "public"}
             )
             |> render_submit()
  end

  test "posting to the board works for a logged-in user", %{
    conn: conn,
    lender: lender,
    team: team
  } do
    conn = log_in(conn, lender)
    {:ok, view, _html} = live(conn, ~p"/teams/#{team.slug}")
    html = view |> form("form[phx-submit='post']", %{body: "Cheering you on!"}) |> render_submit()
    assert html =~ "Cheering you on!"
  end
end
