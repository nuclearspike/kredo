defmodule KivaWeb.ApiAuth do
  @moduledoc """
  Bearer-token authentication for the JSON and GraphQL APIs.

  Tokens are signed with `Phoenix.Token` (stateless; no DB row) and carry the
  user id. Demo-grade — the role on the loaded user is still the authorization
  boundary, re-checked on every protected endpoint, exactly as the session path.
  """
  import Plug.Conn
  alias Kiva.Accounts

  @salt "kiva api auth"
  # 30 days
  @max_age 60 * 60 * 24 * 30

  @doc "Sign a bearer token for `user` (returned by the login endpoint)."
  def sign_token(user), do: Phoenix.Token.sign(KivaWeb.Endpoint, @salt, user.id)

  # OAuth2-compat tokens for the Kiva-compatibility layer. Demo-grade: stateless
  # `Phoenix.Token`s carrying the user id, with distinct salts/lifetimes.
  @refresh_salt "kiva oauth refresh"
  @code_salt "kiva oauth code"
  @access_ttl 60 * 60 * 24 * 30
  @refresh_ttl 60 * 60 * 24 * 365
  @code_ttl 60 * 10

  @doc "Access-token lifetime in seconds (OAuth `expires_in`)."
  def access_ttl, do: @access_ttl

  @doc "Sign a refresh token for `user`."
  def sign_refresh_token(user), do: Phoenix.Token.sign(KivaWeb.Endpoint, @refresh_salt, user.id)

  @doc "Verify a refresh token -> {:ok, user} | {:error, reason}."
  def verify_refresh_token(token) when is_binary(token) do
    with {:ok, uid} <-
           Phoenix.Token.verify(KivaWeb.Endpoint, @refresh_salt, token, max_age: @refresh_ttl),
         user when not is_nil(user) <- Accounts.get_user(uid) do
      {:ok, user}
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  def verify_refresh_token(_), do: {:error, :missing}

  @doc "Sign a short-lived OAuth authorization code for `user`."
  def sign_auth_code(user), do: Phoenix.Token.sign(KivaWeb.Endpoint, @code_salt, user.id)

  @doc "Verify an authorization code -> {:ok, user} | {:error, reason}."
  def verify_auth_code(code) when is_binary(code) do
    with {:ok, uid} <-
           Phoenix.Token.verify(KivaWeb.Endpoint, @code_salt, code, max_age: @code_ttl),
         user when not is_nil(user) <- Accounts.get_user(uid) do
      {:ok, user}
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  def verify_auth_code(_), do: {:error, :missing}

  @doc "Verify a bearer token, returning {:ok, user} or {:error, reason}."
  def verify_token(token) when is_binary(token) do
    case Phoenix.Token.verify(KivaWeb.Endpoint, @salt, token, max_age: @max_age) do
      {:ok, user_id} ->
        case Accounts.get_user(user_id) do
          nil -> {:error, :not_found}
          user -> {:ok, user}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_token(_), do: {:error, :missing}

  @doc """
  Plug: assign `:current_user` from an `Authorization: Bearer <token>` header when
  present and valid. Never halts and never clobbers an already-assigned user (so
  it composes with the session-based `fetch_current_user` on the GraphQL pipe).
  """
  def fetch_api_user(conn, _opts) do
    existing = conn.assigns[:current_user]

    user =
      with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
           {:ok, user} <- verify_token(token) do
        user
      else
        _ -> nil
      end

    assign(conn, :current_user, user || existing)
  end

  @doc "Plug: respond 401 unless an authenticated user was resolved."
  def require_api_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.json(%{errors: %{detail: "Unauthorized"}})
      |> halt()
    end
  end
end
