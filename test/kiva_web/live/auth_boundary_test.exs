defmodule KivaWeb.AuthBoundaryTest do
  @moduledoc "Permission-boundary tests for role-scoped LiveView routes."
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "borrower portal (/portal)" do
    test "anonymous is redirected away", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/portal")
    end

    test "a lender cannot enter the borrower portal", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{role: "lender"}))
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/portal")
    end

    test "a borrower can enter", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{role: "borrower"}))
      {:ok, _view, html} = live(conn, ~p"/portal")
      assert html =~ "My portal"
    end
  end

  describe "admin ops (/admin)" do
    test "a lender cannot enter admin", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{role: "lender"}))
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end

    test "staff and admin can enter", %{conn: _conn} do
      for role <- ["staff", "admin"] do
        conn = log_in(build_conn(), user_fixture(%{role: role}))
        {:ok, _view, html} = live(conn, ~p"/admin")
        assert html =~ "admin operations"
      end
    end
  end

  describe "public loan browse (/loans)" do
    test "is reachable anonymously", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/loans")
      assert html =~ "Lending that builds resilient communities"
    end
  end
end
