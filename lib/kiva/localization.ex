defmodule Kiva.Localization do
  @moduledoc """
  Localization context.

  Multilingual is infrastructure, not a feature. This module owns the supported
  locale set, the fallback chain (`requested -> base -> en`), and locale-aware
  formatting of numeric truth. Per-entity translated text lives in `*_lc`
  sidecar tables (see `Kiva.Localization.Sidecar`, added in Phase 1).
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Locale

  @supported ~w(en de es fr nl)
  @default "en"

  @doc "Locale codes this demo supports."
  def supported_locales, do: @supported

  @doc "The default/base locale."
  def default_locale, do: @default

  def supported?(code), do: code in @supported

  @doc "All enabled locales as rows, ordered by code."
  def list_locales do
    Repo.all(from l in Locale, where: l.enabled == true, order_by: l.code)
  end

  def get_locale(code), do: Repo.get(Locale, code)

  @doc """
  Normalize an arbitrary locale value to a supported code, defaulting to `en`.
  """
  def normalize(code) when is_binary(code) do
    if supported?(code), do: code, else: @default
  end

  def normalize(_), do: @default

  @doc """
  Fallback chain for a requested locale: `requested -> en`.
  English resolves to just `[\"en\"]`.
  """
  def fallback_chain(code) do
    case normalize(code) do
      "en" -> ["en"]
      other -> [other, @default]
    end
  end

  @doc """
  Format an integer cent amount as localized currency. Numeric truth is stored
  once (cents); only presentation is localized.
  """
  def format_money(cents, currency \\ "USD", locale \\ @default) when is_integer(cents) do
    # Cents are shown ONLY when the amount isn't a whole dollar (e.g. a $118.75
    # repayment installment). Round-dollar amounts render without ".00".
    formatted = :erlang.float_to_binary(cents / 100, decimals: 2)
    [int_part, frac_part] = String.split(formatted, ".")
    {thousands, decimal} = separators(locale)
    grouped = group_thousands(int_part, thousands)
    symbol = currency_symbol(currency)
    number = if rem(cents, 100) == 0, do: grouped, else: "#{grouped}#{decimal}#{frac_part}"

    case locale do
      l when l in ["de", "es", "fr", "nl"] -> "#{number} #{symbol}"
      _ -> "#{symbol}#{number}"
    end
  end

  @doc "Locale-aware thousands-grouped integer (e.g. 55_000 -> \"55,000\" / \"55.000\")."
  def format_count(n, locale \\ @default) when is_integer(n) do
    {thousands, _decimal} = separators(locale)
    n |> abs() |> Integer.to_string() |> group_thousands(thousands)
  end

  defp separators("en"), do: {",", "."}
  defp separators(_), do: {".", ","}

  defp currency_symbol("USD"), do: "$"
  defp currency_symbol("EUR"), do: "€"
  defp currency_symbol(other), do: other <> " "

  defp group_thousands(int_str, sep) do
    int_str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
    |> Enum.join(sep)
  end
end
