defmodule KivaWeb.UserAuth do
  @moduledoc """
  Session-based authentication helpers and plugs. Demo-grade: a user id is
  stored in the session; role drives authorization. The model is never the
  permission boundary — every protected route/surface re-checks server-side.
  """
  use KivaWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Kiva.Accounts

  @doc "Log in a user: renew the session, store the id, redirect to their home."
  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> put_session(:locale, user.default_locale_code || Kiva.Localization.default_locale())
    |> put_session(:live_socket_id, "users_sessions:#{user.id}")
    |> redirect(to: signed_in_path(user))
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc "Plug: assign `:current_user` from the session (or nil)."
  def fetch_current_user(conn, _opts) do
    user = with id when not is_nil(id) <- get_session(conn, :user_id), do: Accounts.get_user(id)
    assign(conn, :current_user, user || nil)
  end

  @doc "Plug: require any authenticated user."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access that page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc "Plug: require the current user to hold one of `roles` (list passed as opts)."
  def require_role(conn, roles) do
    roles = List.wrap(roles)
    user = conn.assigns[:current_user]

    if user && user.role in roles do
      conn
    else
      conn
      |> put_flash(:error, "You are not authorized to view that page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  @doc """
  on_mount hooks for LiveViews.

    * `:mount_current_user` — assign current_user if present
    * `:ensure_authenticated` — redirect to /login if absent
    * `{:ensure_role, roles}` — redirect to / unless role matches
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "You must log in.")
       |> Phoenix.LiveView.redirect(to: ~p"/login")}
    end
  end

  def on_mount(:ensure_developer, _params, session, socket) do
    socket = mount_current_user(socket, session)
    user = socket.assigns.current_user

    if user && user.developer_enabled do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Enable developer access to use the portal.")
       |> Phoenix.LiveView.redirect(to: ~p"/developers")}
    end
  end

  def on_mount({:ensure_role, roles}, _params, session, socket) do
    socket = mount_current_user(socket, session)
    user = socket.assigns.current_user

    if user && user.role in List.wrap(roles) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Not authorized.")
       |> Phoenix.LiveView.redirect(to: ~p"/")}
    end
  end

  defp mount_current_user(socket, session) do
    socket =
      Phoenix.Component.assign_new(socket, :current_user, fn ->
        with id when not is_nil(id) <- session["user_id"], do: Accounts.get_user(id)
      end)

    locale = Kiva.Localization.normalize(session["locale"])
    Gettext.put_locale(KivaWeb.Gettext, locale)
    Phoenix.Component.assign(socket, :locale, locale)
  end

  @doc "Role-appropriate landing path after login."
  def signed_in_path(%{role: "borrower"}), do: ~p"/portal"
  def signed_in_path(%{role: "partner"}), do: ~p"/partner"
  def signed_in_path(%{role: role}) when role in ["staff", "admin"], do: ~p"/admin"
  def signed_in_path(_), do: ~p"/loans"
end
