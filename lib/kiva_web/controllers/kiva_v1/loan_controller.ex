defmodule KivaWeb.KivaV1.LoanController do
  @moduledoc "Legacy Kiva REST v1 loan endpoints: search, newest, batch detail, lenders."
  use KivaWeb, :controller

  alias Kiva.Lending
  alias KivaWeb.KivaCompat.{Mapping, Paging}
  alias KivaWeb.KivaV1.{LoanJSON, LenderJSON}

  action_fallback KivaWeb.KivaV1.FallbackController

  def search(conn, params), do: render_search(conn, params, params["sort_by"])
  def newest(conn, params), do: render_search(conn, params, "newest")

  defp render_search(conn, params, sort_by) do
    locale = locale(params)
    {page, per_page} = Paging.page_params(params)

    opts = %{
      statuses: Mapping.search_statuses(params["status"]),
      gender: Mapping.gender_filter(params["gender"]),
      sector: params["sector"],
      country_codes: country_codes(params),
      partner_ids: int_list(params["partner"]),
      q: params["q"],
      locale: locale,
      sort_by: sort_by,
      limit: per_page,
      offset: Paging.offset(page, per_page)
    }

    {loans, total} = Lending.kiva_search(opts)

    body =
      if Paging.ids_only?(params) do
        Paging.envelope("loans", loans, total, page, per_page, params, & &1.id)
      else
        counts = Lending.lender_count_map(Enum.map(loans, & &1.id))

        rows =
          Enum.map(loans, fn l ->
            LoanJSON.summary(l, %{locale: locale, lender_count: Map.get(counts, l.id, 0)})
          end)

        Paging.envelope("loans", rows, total, page, per_page, %{}, & &1.id)
      end

    json(conn, body)
  end

  def show(conn, %{"ids" => ids} = params) do
    locale = locale(params)
    id_list = Paging.parse_ids(ids)
    loans = Lending.kiva_loans_by_ids(id_list, locale)
    counts = Lending.lender_count_map(Enum.map(loans, & &1.id))

    data =
      Enum.map(loans, fn l ->
        LoanJSON.detail(l, %{locale: locale, lender_count: Map.get(counts, l.id, 0)})
      end)

    json(conn, Paging.batch("loans", data))
  end

  def lenders(conn, %{"id" => id} = params) do
    {page, per_page} = Paging.page_params(params)

    case parse_int(id) do
      nil ->
        {:error, :not_found}

      loan_id ->
        {rows, total} =
          Lending.kiva_loan_lenders(loan_id, per_page, Paging.offset(page, per_page))

        data = Enum.map(rows, fn {user, _amt} -> LenderJSON.summary(user, %{}) end)
        json(conn, Paging.envelope("lenders", data, total, page, per_page, %{}, fn _ -> nil end))
    end
  end

  @doc "Faithful to the sunset upstream: the array is always empty."
  def journal_entries(conn, params) do
    {page, per_page} = Paging.page_params(params)
    json(conn, Paging.envelope("journal_entries", [], 0, page, per_page, %{}, fn _ -> nil end))
  end

  # --- params --------------------------------------------------------------

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])

  defp country_codes(params) do
    explicit = csv(params["country_code"])
    region = Mapping.region_codes(params["region"] || "")
    Enum.uniq(explicit ++ region)
  end

  defp csv(nil), do: []
  defp csv(s) when is_binary(s), do: String.split(s, ",", trim: true)

  defp int_list(nil), do: []
  defp int_list(s) when is_binary(s), do: s |> csv() |> Enum.flat_map(&parse_int_list/1)

  defp parse_int_list(s),
    do:
      (case Integer.parse(s) do
         {n, _} -> [n]
         :error -> []
       end)

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end
end
