defmodule Kiva.Localization.Resolver do
  @moduledoc """
  Resolves the best language-content (`*_lc`) row for a requested locale using
  the fallback chain (`requested -> en`), and reports whether a fallback was
  used — so the UI can flag fallback/missing state honestly.

  Pure function over a list of `*_lc` rows; the caller decides which rows to load
  (e.g. only display-eligible statuses for public surfaces).
  """
  alias Kiva.Localization

  # Statuses eligible to display on a public surface. machine/needs_review are
  # shown but badged unreviewed; draft/rejected/stale are hidden.
  @display_statuses ~w(source published approved machine needs_review)

  def display_statuses, do: @display_statuses

  @doc "Keep only `*_lc` rows whose status is display-eligible for public surfaces."
  def display_rows(rows), do: Enum.filter(rows, &(&1.translation_status in @display_statuses))

  @doc "Resolve display-eligible rows for a locale (filter + resolve in one step)."
  def resolve_public(rows, locale), do: rows |> display_rows() |> resolve(locale)

  @type resolution :: %{
          row: struct() | nil,
          locale: String.t() | nil,
          requested: String.t(),
          fallback_used: boolean(),
          missing: boolean()
        }

  @spec resolve([struct()], String.t()) :: resolution()
  def resolve(lc_rows, requested_locale) when is_list(lc_rows) do
    requested = Localization.normalize(requested_locale)
    by_locale = Map.new(lc_rows, &{&1.locale_code, &1})
    chain = Localization.fallback_chain(requested)

    case Enum.find_value(chain, fn code -> if row = by_locale[code], do: {code, row} end) do
      {code, row} ->
        %{
          row: row,
          locale: code,
          requested: requested,
          fallback_used: code != requested,
          missing: false
        }

      nil ->
        %{row: nil, locale: nil, requested: requested, fallback_used: true, missing: true}
    end
  end
end
