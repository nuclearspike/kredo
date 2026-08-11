defmodule KivaWeb.Plugs.SetLocale do
  @moduledoc """
  Resolves the request locale (params > session > user default > base) and sets
  the Gettext locale for the request. Exposes `@locale` to controllers/templates.
  """
  import Plug.Conn
  alias Kiva.Localization

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    locale =
      (conn.params["locale"] ||
         get_session(conn, :locale) ||
         (user && user.default_locale_code) ||
         Localization.default_locale())
      |> Localization.normalize()

    Gettext.put_locale(KivaWeb.Gettext, locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end
end
