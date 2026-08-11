defmodule KivaWeb.KivaV1.FallbackController do
  @moduledoc "Kiva-compat REST error envelopes (`{code, message}`)."
  use KivaWeb, :controller
  alias KivaWeb.KivaCompat.Paging

  def call(conn, {:error, :not_found}),
    do: conn |> put_status(404) |> json(Paging.invalid_resource())

  def call(conn, {:error, :bad_request, param}),
    do: conn |> put_status(400) |> json(Paging.malformed_parameter(param))
end
