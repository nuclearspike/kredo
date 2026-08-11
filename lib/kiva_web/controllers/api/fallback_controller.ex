defmodule KivaWeb.Api.FallbackController do
  @moduledoc "Translates context return values into JSON error responses."
  use KivaWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn |> put_status(:not_found) |> json(%{errors: %{detail: "Not Found"}})
  end

  def call(conn, {:error, :unauthorized}) do
    conn |> put_status(:unauthorized) |> json(%{errors: %{detail: "Unauthorized"}})
  end

  def call(conn, {:error, message}) when is_binary(message) do
    conn |> put_status(:unprocessable_entity) |> json(%{errors: %{detail: message}})
  end
end
