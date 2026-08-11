defmodule KivaWeb.PortalLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures
  alias Kiva.{Messaging, Accounts}

  setup do
    base = borrower_user_fixture()

    {:ok, lender} =
      Accounts.register_user(%{
        email: "pl-lender@kredo.test",
        password: "password",
        role: "lender"
      })

    Messaging.create_encouragement(lender, base.loan.id, "Wonderful work", "en")
    base
  end

  test "borrower sees their loan and encouragement in their language (es)", %{
    conn: conn,
    user: user
  } do
    conn = init_test_session(conn, %{user_id: user.id, locale: "es"})
    {:ok, _view, html} = live(conn, ~p"/portal")
    assert html =~ "Préstamo de tejido"
    assert html =~ "[es←en] Wonderful work"
  end

  test "a non-borrower cannot reach the portal", %{conn: conn} do
    conn = log_in(conn, user_fixture(%{role: "lender"}))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/portal")
  end
end
