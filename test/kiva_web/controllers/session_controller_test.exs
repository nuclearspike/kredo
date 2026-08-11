defmodule KivaWeb.SessionControllerTest do
  use KivaWeb.ConnCase, async: true

  setup do
    %{user: user_fixture(%{email: "s@kredo.test", password: "password", role: "lender"})}
  end

  test "GET /login renders the form", %{conn: conn} do
    conn = get(conn, ~p"/login")
    assert html_response(conn, 200) =~ "Sign in"
  end

  test "valid login logs the user in and redirects", %{conn: conn, user: user} do
    conn = post(conn, ~p"/login", user: %{email: user.email, password: "password"})
    assert get_session(conn, :user_id) == user.id
    assert redirected_to(conn) == ~p"/loans"
  end

  test "invalid login is rejected", %{conn: conn, user: user} do
    conn = post(conn, ~p"/login", user: %{email: user.email, password: "wrong"})
    assert html_response(conn, 401) =~ "Invalid email or password"
    refute get_session(conn, :user_id)
  end

  test "logout clears the session", %{conn: conn, user: user} do
    conn = conn |> log_in(user) |> delete(~p"/logout")
    assert redirected_to(conn) == ~p"/"
    refute get_session(conn, :user_id)
  end
end
