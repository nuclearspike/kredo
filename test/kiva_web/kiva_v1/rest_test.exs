defmodule KivaWeb.KivaV1.RestTest do
  @moduledoc "Parity tests for the legacy Kiva REST v1 compatibility surface."
  use KivaWeb.ConnCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.Repo

  defp set_gender(borrower, g),
    do: Repo.update!(Ecto.Changeset.change(borrower, gender: g))

  describe "GET /v1/loans/search.json" do
    test "returns the Kiva envelope and loan-summary fields", %{conn: conn} do
      loan_fixture()
      body = conn |> get("/v1/loans/search.json") |> json_response(200)

      assert %{"paging" => paging, "loans" => [loan | _]} = body
      assert %{"page" => 1, "total" => total, "page_size" => _, "pages" => _} = paging
      assert total >= 1

      # Kiva field names + money-as-dollars (not cents) + localized name.
      assert loan["name"] == "Weaving loan"
      assert loan["status"] == "fundraising"
      assert loan["loan_amount"] == 1000
      assert loan["funded_amount"] == 400
      assert loan["location"]["country_code"] == "GT"
      assert loan["location"]["country"] == "Guatemala"
      assert loan["sector"] == "Arts"
      assert is_list(loan["description"]["languages"])
    end

    test "ids_only=true returns a flat array of integer ids", %{conn: conn} do
      loan_fixture()
      body = conn |> get("/v1/loans/search.json?ids_only=true") |> json_response(200)
      assert [id | _] = body["loans"]
      assert is_integer(id)
    end

    test "gender filter selects matching borrowers", %{conn: conn} do
      %{borrower: b} = loan_fixture()
      set_gender(b, "female")

      female = conn |> get("/v1/loans/search.json?gender=female") |> json_response(200)
      male = conn |> get("/v1/loans/search.json?gender=male") |> json_response(200)

      assert female["paging"]["total"] == 1
      assert male["paging"]["total"] == 0
    end
  end

  describe "GET /v1/loans/:ids.json" do
    test "batch detail includes terms, borrowers, and multilingual texts (no paging)", %{
      conn: conn
    } do
      %{loan: loan, borrower: b} = loan_fixture()
      set_gender(b, "female")

      body = conn |> get("/v1/loans/#{loan.id}.json") |> json_response(200)
      refute Map.has_key?(body, "paging")
      assert [l] = body["loans"]

      assert [%{"gender" => "F", "first_name" => "Rosa"}] = l["borrowers"]
      assert is_list(l["terms"]["scheduled_payments"])
      assert l["terms"]["repayment_term"] == 8
      assert Map.has_key?(l["description"]["texts"], "en")
      assert l["journal_totals"] == %{"entries" => 0, "bulkEntries" => 0}
    end
  end

  describe "GET /v1/partners.json" do
    test "returns partners with the Kiva shape", %{conn: conn} do
      loan_fixture()
      body = conn |> get("/v1/partners.json") |> json_response(200)
      assert %{"paging" => _, "partners" => [p | _]} = body
      assert p["rating"] == "0.0"
      assert [%{"iso_code" => "GT", "region" => "Central America"} | _] = p["countries"]
    end
  end

  describe "auth" do
    test "POST /oauth/token (password grant) issues a bearer token", %{conn: conn} do
      user_fixture(email: "l@kredo.test", password: "password", role: "lender")

      body =
        conn
        |> post("/oauth/token", %{
          grant_type: "password",
          username: "l@kredo.test",
          password: "password"
        })
        |> json_response(200)

      assert body["token_type"] == "bearer"
      assert is_binary(body["access_token"])
      assert is_binary(body["refresh_token"])
    end

    test "GET /v1/my/loans.json is 401 without a bearer token", %{conn: conn} do
      assert conn |> get("/v1/my/loans.json") |> json_response(401)
    end

    test "GET /v1/my/loans.json works with a bearer token", %{conn: conn} do
      user = user_fixture(role: "lender")
      token = KivaWeb.ApiAuth.sign_token(user)

      body =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/v1/my/loans.json")
        |> json_response(200)

      assert %{"paging" => _, "loans" => _} = body
    end
  end
end
