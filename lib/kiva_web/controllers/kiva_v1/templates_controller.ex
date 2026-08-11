defmodule KivaWeb.KivaV1.TemplatesController do
  @moduledoc "Legacy Kiva REST v1 image-template descriptor."
  use KivaWeb, :controller

  def images(conn, _params) do
    json(conn, %{
      templates: [
        %{id: 1, pattern: "#{base_url(conn)}/img/{image_id}/{size}.jpg"}
      ]
    })
  end

  defp base_url(conn), do: "#{conn.scheme}://#{conn.host}"
end
