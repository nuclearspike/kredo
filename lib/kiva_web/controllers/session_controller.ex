defmodule KivaWeb.SessionController do
  use KivaWeb, :controller

  alias Kiva.Accounts
  alias KivaWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil, page_title: "Sign in")
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> render(:new, error_message: "Invalid email or password", page_title: "Sign in")

      user ->
        conn
        |> put_flash(:info, "Welcome back, #{user.display_name || user.email}!")
        |> UserAuth.log_in_user(user)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out.")
    |> UserAuth.log_out_user()
  end
end
