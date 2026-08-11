defmodule KivaWeb.KivaV1.OauthController do
  @moduledoc """
  OAuth2-compat endpoints mirroring Kiva's `/oauth/authorize` + `/oauth/token`.

  Demo-grade: the authorization code / access / refresh tokens are stateless
  `Phoenix.Token`s (see `KivaWeb.ApiAuth`). Supports the `authorization_code` and
  `refresh_token` grants, plus a `password` grant for headless/testing use.
  """
  use KivaWeb, :controller
  alias Kiva.{Accounts, Developers}
  alias KivaWeb.ApiAuth

  @doc "GET /oauth/authorize — demo: validates credentials, redirects with a code."
  def authorize(conn, %{"redirect_uri" => redirect_uri} = params) do
    with :ok <- validate_client(params["client_id"], redirect_uri),
         email when is_binary(email) <- params["email"],
         pw when is_binary(pw) <- params["password"],
         user when not is_nil(user) <- Accounts.get_user_by_email_and_password(email, pw) do
      code = ApiAuth.sign_auth_code(user)
      sep = if String.contains?(redirect_uri, "?"), do: "&", else: "?"
      redirect(conn, external: redirect_uri <> sep <> "code=" <> URI.encode_www_form(code))
    else
      {:error, :invalid_client} -> conn |> put_status(400) |> json(%{error: "invalid_client"})
      _ -> conn |> put_status(401) |> json(%{error: "access_denied"})
    end
  end

  def authorize(conn, _), do: conn |> put_status(400) |> json(%{error: "invalid_request"})

  @doc "POST /oauth/token — exchange a code / refresh token / credentials for tokens."
  def token(conn, %{"grant_type" => _} = params) do
    if client_ok?(params),
      do: dispatch_token(conn, params),
      else: conn |> put_status(401) |> json(%{error: "invalid_client"})
  end

  def token(conn, _), do: conn |> put_status(400) |> json(%{error: "invalid_request"})

  defp dispatch_token(conn, %{"grant_type" => "authorization_code", "code" => code}),
    do: respond(conn, ApiAuth.verify_auth_code(code))

  defp dispatch_token(conn, %{"grant_type" => "refresh_token", "refresh_token" => rt}),
    do: respond(conn, ApiAuth.verify_refresh_token(rt))

  defp dispatch_token(conn, %{"grant_type" => "password", "username" => email, "password" => pw}),
    do: respond(conn, password_grant(email, pw))

  defp dispatch_token(conn, _),
    do: conn |> put_status(400) |> json(%{error: "unsupported_grant_type"})

  # Additive confidential-client check: only enforced when a client_id is supplied,
  # so the legacy credential-only demo flow (and its tests) keep working.
  defp validate_client(nil, _redirect_uri), do: :ok

  defp validate_client(client_id, redirect_uri) do
    case Developers.get_app_by_client_id(client_id) do
      nil ->
        {:error, :invalid_client}

      app ->
        if Developers.valid_redirect_uri?(app, redirect_uri),
          do: :ok,
          else: {:error, :invalid_client}
    end
  end

  defp client_ok?(%{"client_id" => client_id} = params) when is_binary(client_id) do
    case Developers.get_app_by_client_id(client_id) do
      nil -> false
      app -> Developers.verify_client_secret(app, params["client_secret"] || "")
    end
  end

  defp client_ok?(_), do: true

  defp password_grant(email, pw) do
    case Accounts.get_user_by_email_and_password(email, pw) do
      nil -> {:error, :invalid}
      user -> {:ok, user}
    end
  end

  defp respond(conn, {:ok, user}), do: json(conn, token_response(user))
  defp respond(conn, _), do: conn |> put_status(400) |> json(%{error: "invalid_grant"})

  defp token_response(user) do
    %{
      access_token: ApiAuth.sign_token(user),
      token_type: "bearer",
      expires_in: ApiAuth.access_ttl(),
      refresh_token: ApiAuth.sign_refresh_token(user),
      user_id: user.id
    }
  end
end
