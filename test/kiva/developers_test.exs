defmodule Kiva.DevelopersTest do
  use Kiva.DataCase, async: true

  alias Kiva.{Accounts, Developers, Repo}
  alias Kiva.Developers.ApiKey

  defp user(attrs \\ %{}) do
    {:ok, u} =
      Accounts.register_user(
        Map.merge(
          %{
            email: "d#{System.unique_integer([:positive])}@kredo.test",
            password: "password",
            role: "lender"
          },
          attrs
        )
      )

    u
  end

  describe "applications" do
    test "create_app returns a one-time secret; only the hash is stored" do
      u = user()

      {:ok, {app, secret}} =
        Developers.create_app(u, %{"name" => "A", "redirect_uris" => ["https://x.com/cb"]})

      assert app.app_id =~ ~r/^app_/
      assert is_binary(secret)
      assert app.client_secret_hash != secret
      assert Developers.verify_client_secret(app, secret)
      refute Developers.verify_client_secret(app, "wrong")
      assert Developers.valid_redirect_uri?(app, "https://x.com/cb")
      refute Developers.valid_redirect_uri?(app, "https://evil.com")
    end

    test "rejects invalid redirect URIs" do
      assert {:error, cs} =
               Developers.create_app(user(), %{"name" => "A", "redirect_uris" => ["not-a-url"]})

      assert "must be absolute http(s) URLs" in errors_on(cs).redirect_uris
    end

    test "list_apps / get_app are owner-scoped" do
      u1 = user()
      u2 = user()
      {:ok, {app, _}} = Developers.create_app(u1, %{"name" => "A"})

      assert [_] = Developers.list_apps(u1)
      assert [] = Developers.list_apps(u2)
      assert Developers.get_app(u1, app.app_id)
      refute Developers.get_app(u2, app.app_id)
    end

    test "rotate_secret invalidates the previous secret" do
      {:ok, {app, secret1}} = Developers.create_app(user(), %{"name" => "A"})
      {:ok, {app, secret2}} = Developers.rotate_secret(app)

      refute Developers.verify_client_secret(app, secret1)
      assert Developers.verify_client_secret(app, secret2)
    end
  end

  describe "api keys + authenticate/1" do
    setup do
      u = user()
      {:ok, {app, _}} = Developers.create_app(u, %{"name" => "A"})
      %{user: u, app: app}
    end

    test "happy path resolves to the owner", %{user: u, app: app} do
      {:ok, {_key, raw}} = Developers.create_api_key(app, %{"name" => "prod"})

      assert raw =~ ~r/^kva_live_/
      assert {:ok, %{user: au, app: aa}} = Developers.authenticate(raw)
      assert au.id == u.id
      assert aa.id == app.id
    end

    test "rejects tampered, wrong-prefix, unknown, and nil", %{app: app} do
      {:ok, {_key, raw}} = Developers.create_api_key(app)

      assert :error = Developers.authenticate(raw <> "x")
      assert :error = Developers.authenticate("kva_live_nope_nope")
      assert :error = Developers.authenticate("not-a-key")
      assert :error = Developers.authenticate(nil)
    end

    test "revoked key fails (idempotent revoke)", %{app: app} do
      {:ok, {key, raw}} = Developers.create_api_key(app)
      assert {:ok, _} = Developers.authenticate(raw)

      {:ok, _} = Developers.revoke_api_key(key)
      assert :error = Developers.authenticate(raw)
      assert {:ok, _} = Developers.revoke_api_key(key)
    end

    test "expired key fails", %{app: app} do
      {:ok, {key, raw}} = Developers.create_api_key(app)
      past = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)
      key |> Ecto.Changeset.change(expires_at: past) |> Repo.update!()

      assert :error = Developers.authenticate(raw)
    end

    test "only the hash is persisted (raw never stored)", %{app: app} do
      {:ok, {key, raw}} = Developers.create_api_key(app)
      stored = Repo.get!(ApiKey, key.id)
      refute stored.token_hash == raw
      assert String.length(stored.token_hash) == 64
    end
  end
end
