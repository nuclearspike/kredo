defmodule KivaWeb.PageController do
  use KivaWeb, :controller

  def home(conn, _params) do
    locale = conn.assigns[:locale] || "en"
    featured = Kiva.Lending.list_localized_loans(locale, %{}) |> Enum.take(3)
    render(conn, :home, page_title: "Home", featured: featured)
  end
end
