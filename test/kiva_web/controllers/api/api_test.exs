defmodule KivaWeb.Api.ApiTest do
  @moduledoc """
  HTTP-level coverage for the REST API and token-authenticated GraphQL: the login
  flow, the bearer-token `me` surfaces, and the borrower-image privacy rule
  (image only while a loan is fundraising).
  """
  use KivaWeb.ConnCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.Repo

  # Set the borrower photo directly, bypassing the changeset cast list.
  defp put_image(borrower, url), do: Repo.update!(Ecto.Changeset.change(borrower, image_url: url))

  defp login(conn, email, password \\ "password") do
    conn
    |> post(~p"/api/v2/auth/login", %{email: email, password: password})
    |> json_response(200)
    |> Map.fetch!("token")
  end

  defp auth(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token}")

  describe "POST /api/v2/auth/login" do
    test "valid credentials return a token and the user (no password hash)", %{conn: conn} do
      user_fixture(%{email: "l@kredo.test", password: "password", role: "lender"})

      body =
        conn
        |> post(~p"/api/v2/auth/login", %{email: "l@kredo.test", password: "password"})
        |> json_response(200)

      assert is_binary(body["token"])
      assert body["user"]["email"] == "l@kredo.test"
      assert body["user"]["role"] == "lender"
      refute Map.has_key?(body["user"], "encrypted_password")
      refute Map.has_key?(body["user"], "password")
    end

    test "wrong password is 401", %{conn: conn} do
      user_fixture(%{email: "l@kredo.test", password: "password"})
      conn = post(conn, ~p"/api/v2/auth/login", %{email: "l@kredo.test", password: "nope"})
      assert json_response(conn, 401)["errors"]["detail"] =~ "Invalid"
    end

    test "missing params is 400", %{conn: conn} do
      conn = post(conn, ~p"/api/v2/auth/login", %{email: "x@kredo.test"})
      assert json_response(conn, 400)["errors"]
    end
  end

  describe "borrower-image privacy rule (REST)" do
    test "image is present while the loan is fundraising", %{conn: conn} do
      %{loan: loan, borrower: b} = loan_fixture()
      put_image(b, "/img/rosa.jpg")

      data =
        conn |> get(~p"/api/v2/loans/#{loan.slug}") |> json_response(200) |> Map.fetch!("data")

      assert data["status"] == "fundraising"
      assert data["borrower_image"] == "/img/rosa.jpg"
    end

    test "image is hidden once the loan is no longer fundraising", %{conn: conn} do
      %{loan: loan, borrower: b} =
        loan_fixture(%{status: "completed", funded_amount_cents: 100_000})

      put_image(b, "/img/rosa.jpg")

      data =
        conn |> get(~p"/api/v2/loans/#{loan.slug}") |> json_response(200) |> Map.fetch!("data")

      assert data["status"] == "completed"
      assert data["borrower_image"] == nil
    end

    test "the list endpoint applies the same rule per loan", %{conn: conn} do
      %{borrower: bf} = loan_fixture(%{slug: "fr-loan"})
      put_image(bf, "/img/fund.jpg")

      %{borrower: bc} =
        loan_fixture(%{slug: "done-loan", status: "completed", funded_amount_cents: 100_000})

      put_image(bc, "/img/done.jpg")

      cards = conn |> get(~p"/api/v2/loans") |> json_response(200) |> Map.fetch!("data")
      by_slug = Map.new(cards, &{&1["slug"], &1})

      assert by_slug["fr-loan"]["borrower_image"] == "/img/fund.jpg"
      assert by_slug["done-loan"]["borrower_image"] == nil
    end
  end

  describe "authenticated /api/v2/me" do
    test "is 401 without a token", %{conn: conn} do
      assert conn |> get(~p"/api/v2/me") |> json_response(401)
    end

    test "is 401 with a garbage token", %{conn: conn} do
      assert conn |> auth("not-a-real-token") |> get(~p"/api/v2/me") |> json_response(401)
    end

    test "returns the current user", %{conn: conn} do
      user_fixture(%{email: "me@kredo.test", password: "password", display_name: "Mia"})
      token = login(conn, "me@kredo.test")

      data =
        conn |> auth(token) |> get(~p"/api/v2/me") |> json_response(200) |> Map.fetch!("data")

      assert data["email"] == "me@kredo.test"
      assert data["display_name"] == "Mia"
    end

    test "a lender sees their lendings; borrower_loans is empty", %{conn: conn} do
      %{loan: loan} = loan_fixture()
      lender = user_fixture(%{email: "lender2@kredo.test", role: "lender"})
      Kiva.Portfolio.lend(lender, loan.id, 2500)
      token = login(conn, "lender2@kredo.test")

      data =
        conn
        |> auth(token)
        |> get(~p"/api/v2/me/loans")
        |> json_response(200)
        |> Map.fetch!("data")

      assert [lending] = data["lendings"]
      assert lending["loan_slug"] == loan.slug
      assert lending["amount_cents"] == 2500
      assert data["borrower_loans"] == []
    end

    test "a borrower's own loans come back with the image rule applied", %{conn: conn} do
      %{user: user, borrower: b} = borrower_user_fixture()
      put_image(b, "/img/rosa.jpg")
      token = login(conn, user.email)

      data =
        conn
        |> auth(token)
        |> get(~p"/api/v2/me/loans")
        |> json_response(200)
        |> Map.fetch!("data")

      assert [loan | _] = data["borrower_loans"]
      assert loan["status"] == "fundraising"
      assert loan["borrower_image"] == "/img/rosa.jpg"
    end

    test "me/teams and me/portfolio for a fresh lender", %{conn: conn} do
      user_fixture(%{email: "p2@kredo.test", role: "lender"})
      token = login(conn, "p2@kredo.test")

      assert conn
             |> auth(token)
             |> get(~p"/api/v2/me/teams")
             |> json_response(200)
             |> Map.fetch!("data") ==
               []

      pf =
        conn
        |> auth(token)
        |> get(~p"/api/v2/me/portfolio")
        |> json_response(200)
        |> Map.fetch!("data")

      assert pf["count"] == 0
      assert pf["total_cents"] == 0
    end
  end

  describe "GraphQL over a bearer token" do
    defp gql(conn, query) do
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/graphql", Jason.encode!(%{query: query}))
      |> json_response(200)
    end

    test "`me` resolves with a token in the Authorization header", %{conn: conn} do
      user_fixture(%{email: "gql@kredo.test", role: "lender", display_name: "Gee"})
      token = login(conn, "gql@kredo.test")

      body = conn |> auth(token) |> gql("{ me { email role } }")
      assert body["data"]["me"]["email"] == "gql@kredo.test"
      assert body["data"]["me"]["role"] == "lender"
    end

    test "`me` is unauthorized without a token", %{conn: conn} do
      body = gql(conn, "{ me { email } }")
      assert body["data"]["me"] == nil
      assert [%{"message" => msg} | _] = body["errors"]
      assert msg =~ "unauthorized"
    end
  end
end
