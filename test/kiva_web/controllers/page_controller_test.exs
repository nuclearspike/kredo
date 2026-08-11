defmodule KivaWeb.PageControllerTest do
  use KivaWeb.ConnCase, async: true

  test "GET / renders the localized landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Loans that change lives"
    assert body =~ "borrower@kredo.test"
    # globe dropdown present
    assert body =~ "Nederlands"
  end

  test "GET /locale/:locale sets the session locale and redirects back", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("referer", "http://localhost/")
      |> get(~p"/locale/es")

    assert redirected_to(conn) == "/"
    assert get_session(conn, :locale) == "es"
  end

  test "unknown locale is normalized to en", %{conn: conn} do
    conn = get(conn, ~p"/locale/xx")
    assert get_session(conn, :locale) == "en"
  end
end
