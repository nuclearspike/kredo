defmodule KivaWeb.KivaCompat.Paging do
  @moduledoc """
  Pagination + envelope helpers for the legacy Kiva REST v1 surface.

  Kiva wraps every collection as `%{"paging" => %{page,total,page_size,pages}, <key> => [...]}`
  (1-based pages, `page`/`per_page` query params), and emits a flat array of integer
  ids when `ids_only=true`. Batch `:ids` detail endpoints omit `paging` entirely.
  Errors use `%{"code" => "org.kiva.<Type>", "message" => ...}`.
  """

  @default_page_size 20
  @max_page_size 500

  @doc "Parse `page`/`per_page` (a.k.a. `page_size`) params into 1-based {page, per_page}."
  def page_params(params, default_size \\ @default_page_size) do
    page = params |> Map.get("page") |> to_int(1) |> max(1)

    per_page =
      params
      |> Map.get("per_page", Map.get(params, "page_size"))
      |> to_int(default_size)
      |> clamp(1, @max_page_size)

    {page, per_page}
  end

  @doc "SQL offset for a 1-based page."
  def offset(page, per_page), do: (page - 1) * per_page

  @doc """
  Build a paged collection envelope: `%{"paging" => ..., key => rows}`. When
  `params["ids_only"]` is truthy, `rows` is replaced by `id_fun.(row)` for each row.
  """
  def envelope(key, rows, total, page, per_page, params \\ %{}, id_fun \\ & &1.id) do
    pages = if per_page > 0, do: ceil(total / per_page), else: 0
    paging = %{page: page, total: total, page_size: per_page, pages: pages}

    data = if ids_only?(params), do: Enum.map(rows, id_fun), else: rows
    %{key => data, paging: paging}
  end

  @doc "Batch `:ids` detail response — just the data array under `key`, no paging."
  def batch(key, rows), do: %{key => rows}

  @doc "Whether the request asked for `ids_only=true`."
  def ids_only?(params), do: Map.get(params, "ids_only") in ["true", "1", true]

  @doc """
  Parse a comma-separated `:ids` path segment into a list of integers (≤100, Kiva's
  batch cap). Drops non-integer segments rather than erroring, matching Kiva.
  """
  def parse_ids(ids) when is_binary(ids) do
    ids
    |> String.split(",", trim: true)
    |> Enum.map(&Integer.parse/1)
    |> Enum.flat_map(fn
      {n, _} -> [n]
      :error -> []
    end)
    |> Enum.take(100)
  end

  def parse_ids(_), do: []

  @doc "Kiva error body for a malformed query parameter (HTTP 400)."
  def malformed_parameter(param),
    do: %{
      code: "org.kiva.MalformedParameter",
      message: "The value for “#{param}” is improperly formed."
    }

  @doc "Kiva error body for an unknown resource (HTTP 404)."
  def invalid_resource(message \\ "The requested resource could not be found."),
    do: %{code: "org.kiva.InvalidResource", message: message}

  defp to_int(nil, default), do: default
  defp to_int(n, _default) when is_integer(n), do: n

  defp to_int(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_int(_, default), do: default

  defp clamp(n, lo, hi), do: n |> max(lo) |> min(hi)
end
