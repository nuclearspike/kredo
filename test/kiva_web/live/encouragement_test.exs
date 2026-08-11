defmodule KivaWeb.EncouragementTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures
  alias Kiva.Accounts

  setup do
    {:ok, lender} =
      Accounts.register_user(%{
        email: "e-lender@kredo.test",
        password: "password",
        role: "lender"
      })

    %{lender: lender, loan: loan_fixture().loan}
  end

  test "a lender sends encouragement; it is moderated and shown", %{
    conn: conn,
    lender: lender,
    loan: loan
  } do
    conn = log_in(conn, lender)
    {:ok, view, _} = live(conn, ~p"/loans/#{loan.slug}")
    html = view |> form("form[phx-submit='encourage']", %{body: "Keep it up!"}) |> render_submit()
    assert html =~ "Keep it up!"
  end

  test "unkind encouragement is blocked with a flash", %{conn: conn, lender: lender, loan: loan} do
    conn = log_in(conn, lender)
    {:ok, view, _} = live(conn, ~p"/loans/#{loan.slug}")
    html = view |> form("form[phx-submit='encourage']", %{body: "you idiot"}) |> render_submit()
    assert html =~ "unkind"
  end
end
