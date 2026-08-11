defmodule KivaWeb.ImageController do
  @moduledoc """
  Serves a deterministic placeholder "borrower photo" at the legacy
  `/img/<size>/<id>.jpg` URL that KivaLens requests, so the app runs fully
  offline with no Kiva CDN. The id is a one-way hash of the borrower image URL
  (see `KivaWeb.KivaCompat.Mapping.legacy_image/1`), so the original file can't be
  recovered — a stable colored avatar keyed on the id is the stand-in. Browsers
  render by response Content-Type, so an SVG served at the `.jpg` path displays
  fine, and the same loan always renders the same placeholder.
  """
  use KivaWeb, :controller

  # Kiva sizes come in as "s113" / "w480" / "w800"; we only need the pixel box.
  def show(conn, %{"size" => size, "filename" => filename}) do
    id = Path.rootname(filename)

    box =
      case Integer.parse(String.replace(size, ~r/\D/, "")) do
        {n, _} when n > 0 and n <= 2000 -> n
        _ -> 240
      end

    conn
    |> put_resp_content_type("image/svg+xml")
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> send_resp(200, placeholder_svg(id, box))
  end

  # Colored avatar (head + shoulders); hue is deterministic per id.
  defp placeholder_svg(id, box) do
    hue = rem(:erlang.phash2(id), 360)

    ~s|<svg xmlns="http://www.w3.org/2000/svg" width="#{box}" height="#{box}" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice"><rect width="100" height="100" fill="hsl(#{hue} 45% 55%)"/><circle cx="50" cy="38" r="16" fill="#ffffff" fill-opacity="0.9"/><path d="M22 90 C22 70 34 60 50 60 C66 60 78 70 78 90 Z" fill="#ffffff" fill-opacity="0.9"/></svg>|
  end
end
