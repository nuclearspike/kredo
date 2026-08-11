defmodule KivaWeb.Api.FaqController do
  @moduledoc "Public localized FAQ entries."
  use KivaWeb, :controller

  alias Kiva.Content
  alias KivaWeb.Api.Serializer

  def index(conn, params) do
    locale = Kiva.Localization.normalize(params["locale"])
    data = Content.list_localized_faqs(locale) |> Enum.map(&Serializer.faq/1)
    json(conn, %{data: data})
  end
end
