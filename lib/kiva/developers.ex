defmodule Kiva.Developers do
  @moduledoc """
  Developer portal context: applications (which double as OAuth2 clients) and
  API keys for the bespoke Platform API.

  Secrets are never stored in the clear: an app's client secret and a key's raw
  value are returned exactly once at creation and only their SHA-256 hashes are
  persisted. API keys verify via an indexed `key_id` lookup + constant-time
  hash compare (fast; bcrypt would be both too slow per-request and unindexable).
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Accounts
  alias Kiva.Developers.{App, ApiKey}

  # --- Applications (OAuth clients) ---------------------------------------

  def list_apps(owner) do
    Repo.all(
      from a in App,
        where: a.owner_user_id == ^uid(owner),
        order_by: [desc: a.inserted_at],
        preload: [:api_keys]
    )
  end

  @doc "An app owned by `owner`, by its public app_id (scoped — never trusts input)."
  def get_app(owner, app_id) do
    Repo.one(
      from a in App,
        where: a.owner_user_id == ^uid(owner) and a.app_id == ^app_id,
        preload: [:api_keys]
    )
  end

  @doc "An app by client_id (app_id), unscoped — for the OAuth client lookup."
  def get_app_by_client_id(app_id) when is_binary(app_id), do: Repo.get_by(App, app_id: app_id)
  def get_app_by_client_id(_), do: nil

  @doc "Create an app for `owner`; returns `{:ok, {app, client_secret}}` (secret shown once)."
  def create_app(owner, attrs) do
    secret = "secret_" <> rand(24)

    %App{}
    |> App.changeset(put_uris(attrs))
    |> Ecto.Changeset.change(
      owner_user_id: uid(owner),
      app_id: "app_" <> rand(12),
      client_secret_hash: sha256(secret),
      status: "active"
    )
    |> Repo.insert()
    |> case do
      {:ok, app} -> {:ok, {app, secret}}
      err -> err
    end
  end

  def update_app(%App{} = app, attrs) do
    app |> App.changeset(put_uris(attrs)) |> Repo.update()
  end

  @doc "Rotate the client secret; returns `{:ok, {app, new_secret}}`. Invalidates the old one."
  def rotate_secret(%App{} = app) do
    secret = "secret_" <> rand(24)

    case app |> Ecto.Changeset.change(client_secret_hash: sha256(secret)) |> Repo.update() do
      {:ok, app} -> {:ok, {app, secret}}
      err -> err
    end
  end

  @doc "Constant-time client-secret check for the OAuth confidential-client flow."
  def verify_client_secret(%App{client_secret_hash: hash}, secret) when is_binary(secret),
    do: Plug.Crypto.secure_compare(hash, sha256(secret))

  def verify_client_secret(_, _), do: false

  @doc "Whether `uri` is one of the app's registered redirect URIs (exact match)."
  def valid_redirect_uri?(%App{redirect_uris: uris}, uri), do: uri in uris

  # --- API keys ------------------------------------------------------------

  def list_api_keys(%App{id: id}) do
    Repo.all(from k in ApiKey, where: k.developer_app_id == ^id, order_by: [desc: k.inserted_at])
  end

  @doc "Mint a key for `app`; returns `{:ok, {key, raw}}`. `raw` is shown once."
  def create_api_key(%App{} = app, attrs \\ %{}) do
    key_id = rand(9)
    secret = rand(24)
    raw = "kva_live_" <> key_id <> "_" <> secret

    %ApiKey{}
    |> ApiKey.changeset(%{
      developer_app_id: app.id,
      key_id: key_id,
      prefix: "kva_live_" <> String.slice(key_id, 0, 8),
      last4: String.slice(secret, -4, 4),
      token_hash: sha256(raw),
      name: attrs["name"] || attrs[:name]
    })
    |> Repo.insert()
    |> case do
      {:ok, key} -> {:ok, {key, raw}}
      err -> err
    end
  end

  @doc "Revoke a key (idempotent)."
  def revoke_api_key(%ApiKey{revoked_at: nil} = key),
    do: key |> Ecto.Changeset.change(revoked_at: now()) |> Repo.update()

  def revoke_api_key(%ApiKey{} = key), do: {:ok, key}

  @doc """
  Resolve a raw API key to its owner. Returns `{:ok, %{user, app, key}}` for a
  valid, active key, else `:error`.
  """
  def authenticate("kva_live_" <> rest = raw) do
    with [key_id, _secret] <- String.split(rest, "_", parts: 2),
         %ApiKey{} = key <- Repo.get_by(ApiKey, key_id: key_id),
         true <- active?(key),
         true <- Plug.Crypto.secure_compare(key.token_hash, sha256(raw)),
         %App{} = app <- Repo.preload(key, :app).app,
         %{} = user <- Accounts.get_user(app.owner_user_id) do
      {:ok, %{user: user, app: app, key: key}}
    else
      _ -> :error
    end
  end

  def authenticate(_), do: :error

  @doc "Stamp `last_used_at` off the request path (best-effort; never blocks)."
  def touch_last_used(%ApiKey{id: id}) do
    if Application.get_env(:kiva, :stamp_api_key_usage, true) do
      Task.Supervisor.start_child(Kiva.TaskSupervisor, fn ->
        # Best-effort, off the request path: never let a stamp failure crash the
        # task or pollute logs.
        try do
          # Throttle: stamp at most once a minute per key (a no-op WHERE most of
          # the time) to avoid a DB write on every authenticated request.
          cutoff = DateTime.add(now(), -60, :second)

          from(k in ApiKey,
            where: k.id == ^id and (is_nil(k.last_used_at) or k.last_used_at < ^cutoff)
          )
          |> Repo.update_all(set: [last_used_at: now()])
        rescue
          _ -> :ok
        end
      end)
    end

    :ok
  end

  # --- seed helpers --------------------------------------------------------

  @doc "Idempotent app upsert for seeds; pass a fixed `app_id` + `client_secret`."
  def upsert_app(owner, app_id, client_secret, attrs) do
    case get_app_by_client_id(app_id) do
      %App{} = app ->
        update_app(app, attrs)
        app

      nil ->
        %App{}
        |> App.changeset(put_uris(attrs))
        |> Ecto.Changeset.change(
          owner_user_id: uid(owner),
          app_id: app_id,
          client_secret_hash: sha256(client_secret),
          status: "active"
        )
        |> Repo.insert!()
    end
  end

  @doc "Idempotent API-key upsert for seeds from a fixed raw key (so docs can show it)."
  def upsert_api_key(%App{} = app, raw, name) do
    "kva_live_" <> rest = raw
    [key_id, secret] = String.split(rest, "_", parts: 2)

    case Repo.get_by(ApiKey, key_id: key_id) do
      %ApiKey{} = key ->
        key

      nil ->
        %ApiKey{}
        |> ApiKey.changeset(%{
          developer_app_id: app.id,
          key_id: key_id,
          prefix: "kva_live_" <> String.slice(key_id, 0, 8),
          last4: String.slice(secret, -4, 4),
          token_hash: sha256(raw),
          name: name
        })
        |> Repo.insert!()
    end
  end

  # --- internals -----------------------------------------------------------

  defp active?(%ApiKey{revoked_at: nil, expires_at: nil}), do: true

  defp active?(%ApiKey{revoked_at: nil, expires_at: exp}),
    do: DateTime.compare(exp, DateTime.utc_now()) == :gt

  defp active?(_), do: false

  defp put_uris(attrs) do
    case attrs["redirect_uris"] || attrs[:redirect_uris] do
      s when is_binary(s) ->
        Map.put(attrs, "redirect_uris", String.split(s, [",", "\n", " "], trim: true))

      _ ->
        attrs
    end
  end

  # base32 (lowercased) avoids `_`/`-`, which matter because the API-key format
  # uses `_` as the key_id/secret delimiter (`kva_live_<key_id>_<secret>`).
  defp rand(bytes),
    do: :crypto.strong_rand_bytes(bytes) |> Base.encode32(padding: false) |> String.downcase()

  defp sha256(s), do: :crypto.hash(:sha256, s) |> Base.encode16(case: :lower)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp uid(%{id: id}), do: id
  defp uid(id) when is_integer(id), do: id
end
