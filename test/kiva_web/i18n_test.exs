defmodule KivaWeb.I18nTest do
  @moduledoc "The chrome must actually switch language via the session locale."
  use KivaWeb.ConnCase, async: true

  test "home renders Spanish chrome when locale is es", %{conn: conn} do
    conn = conn |> init_test_session(%{locale: "es"}) |> get(~p"/")
    body = html_response(conn, 200)
    assert body =~ "Iniciar sesión"
    assert body =~ "Préstamos"
  end

  test "home renders German chrome when locale is de", %{conn: conn} do
    conn = conn |> init_test_session(%{locale: "de"}) |> get(~p"/")
    body = html_response(conn, 200)
    assert body =~ "Anmelden"
    assert body =~ "Darlehen"
  end

  test "defaults to English", %{conn: conn} do
    body = conn |> get(~p"/") |> html_response(200)
    assert body =~ "Loans that change lives"
  end
end
