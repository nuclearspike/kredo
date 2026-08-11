defmodule KivaWeb.Api.AuthController do
  @moduledoc "Exchanges email + password for a bearer token."
  use KivaWeb, :controller

  alias Kiva.Accounts
  alias KivaWeb.ApiAuth
  alias KivaWeb.Api.Serializer

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "Invalid email or password"}})

      user ->
        json(conn, %{token: ApiAuth.sign_token(user), user: Serializer.user(user)})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "email and password are required"}})
  end
end
