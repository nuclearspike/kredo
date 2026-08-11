defmodule KivaWeb.ApiKeyAuth do
  @moduledoc """
  API-key authentication for the bespoke Platform API.

  Resolves a `kva_live_…` key from `Authorization: Bearer …` or `X-API-Key` to its
  owning user. Composes **before** the Phoenix.Token bearer plug
  (`KivaWeb.ApiAuth.fetch_api_user`): the `kva_` prefix means OAuth/login bearer
  tokens fall through untouched. Never halts; on a valid key it wins over an
  already-assigned session user (explicit credential beats ambient cookie), and
  on no/invalid key it leaves existing assigns alone.
  """
  import Plug.Conn
  alias Kiva.Developers

  def fetch_api_key_user(conn, _opts) do
    with raw when is_binary(raw) <- raw_key(conn),
         {:ok, %{user: user, app: app, key: key}} <- Developers.authenticate(raw) do
      Developers.touch_last_used(key)

      conn
      |> assign(:current_user, user)
      |> assign(:api_app, app)
      |> assign(:auth_method, :api_key)
    else
      _ -> conn
    end
  end

  # Bearer `kva_…` takes precedence; otherwise the `X-API-Key` header.
  defp raw_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer kva_" <> rest] ->
        "kva_" <> rest

      _ ->
        case get_req_header(conn, "x-api-key") do
          [key | _] -> key
          _ -> nil
        end
    end
  end
end
