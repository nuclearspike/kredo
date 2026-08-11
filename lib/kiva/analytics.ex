defmodule Kiva.Analytics do
  @moduledoc """
  Admin distribution analytics — live aggregates over the canonical tables (no
  read-model snapshots; demo scale). Answers “where are the loans, the funding,
  the translation coverage, and the AI usage concentrated?” for the AdminLive
  dashboard.
  """
  import Ecto.Query, warn: false
  alias Kiva.{Repo, Taxonomy}
  alias Kiva.Lending.Loan

  def overview(locale) do
    %{
      by_status: by_status(),
      by_country: by_country(),
      by_sector: by_sector(locale),
      translation_coverage: translation_coverage(),
      ai_usage: ai_usage()
    }
  end

  defp by_status do
    Repo.all(
      from l in Loan,
        group_by: l.status,
        select: {l.status, count(l.id)},
        order_by: [desc: count(l.id)]
    )
  end

  defp by_country do
    Repo.all(
      from l in Loan,
        where: not is_nil(l.country_code),
        group_by: l.country_code,
        select: {l.country_code, count(l.id)},
        order_by: [desc: count(l.id)]
    )
  end

  defp by_sector(locale) do
    names = Map.new(Taxonomy.list_sectors(locale), &{&1.id, &1.name})

    Repo.all(
      from l in Loan,
        where: not is_nil(l.sector_id),
        group_by: l.sector_id,
        select: {l.sector_id, sum(l.funded_amount_cents)}
    )
    |> Enum.map(fn {sid, cents} -> {Map.get(names, sid, "—"), cents || 0} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp translation_coverage do
    Repo.all(
      from lc in "loans_lc",
        group_by: lc.locale_code,
        select: {lc.locale_code, count(lc.id)},
        order_by: lc.locale_code
    )
  end

  defp ai_usage do
    Repo.all(from t in "ai_tool_calls", group_by: t.allowed, select: {t.allowed, count(t.id)})
    |> Enum.map(fn {allowed, n} -> {(allowed && "allowed") || "denied", n} end)
  end
end
