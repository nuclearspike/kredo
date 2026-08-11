defmodule KivaWeb.LocaleController do
  use KivaWeb, :controller

  alias Kiva.{Accounts, Localization}

  @doc """
  Globe-dropdown handler. Sets the session locale and (if logged in) persists it
  as the user's default, then returns to the referring page.
  """
  def update(conn, %{"locale" => locale}) do
    locale = Localization.normalize(locale)

    if user = conn.assigns[:current_user] do
      Accounts.update_user_locale(user, locale)
    end

    back =
      case get_req_header(conn, "referer") do
        [ref | _] -> URI.parse(ref).path || "/"
        _ -> "/"
      end

    conn
    |> put_session(:locale, locale)
    |> redirect(to: back)
  end
end
