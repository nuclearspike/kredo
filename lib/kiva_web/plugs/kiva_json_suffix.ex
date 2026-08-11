defmodule KivaWeb.Plugs.KivaJsonSuffix do
  @moduledoc """
  Endpoint plug: lets the Kiva-compat REST routes be requested with the legacy
  `.json` suffix (e.g. `/v1/loans/search.json`, `/v1/loans/305,306.json`) without
  baking the suffix into every route. Runs BEFORE the Router so it rewrites
  `path_info`; only touches `/v1/*` so the rest of the app is unaffected.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: ["v1" | _] = info} = conn, _opts) do
    case List.last(info) do
      seg when is_binary(seg) ->
        cond do
          String.ends_with?(seg, ".json") ->
            rewrite(conn, info, String.replace_suffix(seg, ".json", ""))

          String.ends_with?(seg, ".xml") ->
            rewrite(conn, info, String.replace_suffix(seg, ".xml", ""))

          true ->
            conn
        end

      _ ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp rewrite(conn, info, stripped) do
    new_info = List.replace_at(info, -1, stripped)
    %{conn | path_info: new_info, request_path: "/" <> Enum.join(new_info, "/")}
  end
end
