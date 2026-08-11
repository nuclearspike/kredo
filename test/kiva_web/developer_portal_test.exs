defmodule KivaWeb.DeveloperPortalTest do
  use KivaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Kiva.{Accounts, Developers}

  defp dev_with_key(attrs \\ %{}) do
    user =
      user_fixture(
        Map.merge(
          %{email: "dev#{System.unique_integer([:positive])}@kredo.test", role: "lender"},
          attrs
        )
      )

    {:ok, _} = Accounts.enable_developer(user)

    {:ok, {app, secret}} =
      Developers.create_app(user, %{"name" => "A", "redirect_uris" => ["https://x.com/cb"]})

    {:ok, {_key, raw}} = Developers.create_api_key(app)
    %{user: user, app: app, secret: secret, key: raw}
  end

  describe "API-key auth on /api/v2" do
    test "a valid key resolves to the owner on /api/v2/me", %{conn: conn} do
      %{user: user, key: key} = dev_with_key()

      data =
        conn
        |> put_req_header("authorization", "Bearer #{key}")
        |> get(~p"/api/v2/me")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["email"] == user.email
    end

    test "the X-API-Key header also works", %{conn: conn} do
      %{key: key} = dev_with_key()
      assert conn |> put_req_header("x-api-key", key) |> get(~p"/api/v2/me") |> json_response(200)
    end

    test "no key is 401", %{conn: conn} do
      assert conn |> get(~p"/api/v2/me") |> json_response(401)
    end

    test "a key authenticates the GraphQL `me` query", %{conn: conn} do
      %{user: user, key: key} = dev_with_key()

      body =
        conn
        |> put_req_header("authorization", "Bearer #{key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/graphql", Jason.encode!(%{query: "{ me { email } }"}))
        |> json_response(200)

      assert body["data"]["me"]["email"] == user.email
    end
  end

  describe "OAuth2 client validation (additive)" do
    test "valid client_id + secret issues a token", %{conn: conn} do
      %{user: user, app: app, secret: secret} = dev_with_key()

      body =
        conn
        |> post("/oauth/token", %{
          grant_type: "password",
          username: user.email,
          password: "password",
          client_id: app.app_id,
          client_secret: secret
        })
        |> json_response(200)

      assert body["token_type"] == "bearer"
    end

    test "wrong client_secret is 401 invalid_client", %{conn: conn} do
      %{user: user, app: app} = dev_with_key()

      conn =
        post(conn, "/oauth/token", %{
          grant_type: "password",
          username: user.email,
          password: "password",
          client_id: app.app_id,
          client_secret: "wrong"
        })

      assert json_response(conn, 401)["error"] == "invalid_client"
    end

    test "no client_id still works (back-compat with the existing flow)", %{conn: conn} do
      user =
        user_fixture(%{
          email: "oauth#{System.unique_integer([:positive])}@kredo.test",
          role: "lender"
        })

      body =
        conn
        |> post("/oauth/token", %{
          grant_type: "password",
          username: user.email,
          password: "password"
        })
        |> json_response(200)

      assert body["access_token"]
    end
  end

  describe "developer capability" do
    test "a non-developer is redirected away from /developer", %{conn: conn} do
      user = user_fixture(%{role: "lender"})
      conn = conn |> log_in(user) |> get(~p"/developer")
      assert redirected_to(conn) =~ "/developers"
    end

    test "enable flips the capability and lands on the dashboard", %{conn: conn} do
      user = user_fixture(%{role: "lender"})
      conn = conn |> log_in(user) |> post(~p"/developers/enable")

      assert redirected_to(conn) == ~p"/developer"
      assert Accounts.get_user(user.id).developer_enabled
    end

    test "a developer can load the dashboard", %{conn: conn} do
      user = user_fixture(%{role: "lender"})
      {:ok, _} = Accounts.enable_developer(user)
      conn = conn |> log_in(user) |> get(~p"/developer")
      assert html_response(conn, 200) =~ "Developer dashboard"
    end
  end

  describe "public docs" do
    test "/developers renders the landing", %{conn: conn} do
      assert conn |> get(~p"/developers") |> html_response(200) =~ "Kredo for developers"
    end

    test "/developers/agents.md returns markdown for all surfaces", %{conn: conn} do
      body = conn |> get("/developers/agents.md") |> response(200)
      assert body =~ "Platform REST (v2)"
      assert body =~ "Kiva Legacy REST"
      assert body =~ "/api/v2/me"
    end
  end

  describe "AI query builder" do
    test "submit is async — shows loading immediately, then renders the result", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/developers")
      lv |> element("button[phx-value-id=ai_builder]") |> render_click()

      loading =
        lv
        |> form("form[phx-submit=build]", %{
          intent: "list loans",
          surface: "platform_rest",
          language: "curl"
        })
        |> render_submit()

      assert loading =~ "Composing your request"

      # config/test.exs disables the LLM, so this resolves via the deterministic
      # fallback inside the async task.
      done = render_async(lv)
      assert done =~ "/api/v2"
      refute done =~ "Composing your request"
    end
  end
end
