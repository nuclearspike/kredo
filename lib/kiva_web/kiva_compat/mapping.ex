defmodule KivaWeb.KivaCompat.Mapping do
  @moduledoc """
  The Kiva-compatibility adapter core.

  Pure functions mapping our data model (`Kiva.Lending.Loan`, `Kiva.Partners`,
  `Kiva.Borrowers`, ...) onto the **real Kiva** field shapes — shared by both the
  legacy REST v1 JSON views and the modern Absinthe GraphQL resolvers so the two
  surfaces never drift. Field/enum names here mirror the live Kiva API (June 2026).

  Money is stored in cents; Kiva exposes dollars. Loan status, gender, geo, and
  distribution model all differ between our model and Kiva's and are translated here.
  """
  alias Kiva.Localization.Resolver

  # --- Money ---------------------------------------------------------------

  @doc "Legacy REST money: a JSON number (integer for whole dollars, else 2dp float)."
  def money_number(nil), do: 0

  def money_number(cents) when is_integer(cents) do
    if rem(cents, 100) == 0, do: div(cents, 100), else: Float.round(cents / 100, 2)
  end

  @doc ~S|GraphQL `Money` scalar: a fixed 2-decimal string, e.g. 120000 -> "1200.00".|
  def money_string(nil), do: "0.00"

  def money_string(cents) when is_integer(cents),
    do: :erlang.float_to_binary(cents / 100, decimals: 2)

  # --- Loan status ---------------------------------------------------------
  # Our statuses: fundraising funded funded_disbursed repaying delinquent
  #               completed defaulted draft (+ review states).

  @doc "Legacy REST `status` string for a loan."
  def legacy_status(%{status: s}), do: legacy_status_for(s)
  defp legacy_status_for("fundraising"), do: "fundraising"
  defp legacy_status_for("funded"), do: "funded"
  defp legacy_status_for("funded_disbursed"), do: "funded"
  defp legacy_status_for("repaying"), do: "in_repayment"
  defp legacy_status_for("delinquent"), do: "in_repayment"
  defp legacy_status_for("completed"), do: "paid"
  defp legacy_status_for("defaulted"), do: "defaulted"
  defp legacy_status_for(other), do: other

  @doc "GraphQL `LoanStatusEnum` value (atom) for a loan."
  def gql_status(%{status: s}), do: gql_status_for(s)
  defp gql_status_for("fundraising"), do: :fundraising
  defp gql_status_for("funded"), do: :funded
  defp gql_status_for("funded_disbursed"), do: :raised
  defp gql_status_for("repaying"), do: :paying_back
  defp gql_status_for("delinquent"), do: :paying_back
  defp gql_status_for("completed"), do: :ended
  defp gql_status_for("defaulted"), do: :defaulted
  defp gql_status_for(_), do: :inactive

  @doc "Whether a loan is delinquent (Kiva exposes this as a separate boolean)."
  def delinquent?(%{status: "delinquent"}), do: true
  def delinquent?(_), do: false

  @doc """
  Our loan statuses that satisfy a Kiva search `status` value. Used to translate
  the inbound filter; the legacy API accepts a wider enum than the modern one.
  Returns `nil` for "all"/unknown (caller applies the default public set).
  """
  def search_statuses(nil), do: nil
  def search_statuses("fundraising"), do: ["fundraising"]
  def search_statuses("funded"), do: ["funded", "funded_disbursed"]
  def search_statuses("in_repayment"), do: ["repaying", "delinquent"]
  def search_statuses("paid"), do: ["completed"]
  def search_statuses("defaulted"), do: ["defaulted"]
  def search_statuses("expired"), do: ["expired"]
  def search_statuses("all"), do: nil
  def search_statuses(_), do: nil

  # --- Gender --------------------------------------------------------------

  @doc ~S|Legacy `borrowers[].gender`: "M"/"F" (Kiva's two-value field); nil if unknown.|
  def legacy_gender(%{gender: "female"}), do: "F"
  def legacy_gender(%{gender: "male"}), do: "M"
  def legacy_gender(_), do: nil

  @doc "GraphQL `GenderEnum` (atom)."
  def gql_gender(%{gender: "female"}), do: :female
  def gql_gender(%{gender: "male"}), do: :male
  def gql_gender(%{gender: "nonbinary"}), do: :nonbinary
  def gql_gender(_), do: :unspecified

  @doc "Our borrower `gender` value matching a Kiva gender filter (\"male\"/\"female\")."
  def gender_filter("male"), do: "male"
  def gender_filter("female"), do: "female"
  def gender_filter("M"), do: "male"
  def gender_filter("F"), do: "female"
  def gender_filter(_), do: nil

  # --- Distribution model (trust_model) ------------------------------------

  @doc "Is this a partner-facilitated loan (vs a direct loan)?"
  def partner_loan?(%{partner_id: pid, trust_model: tm}),
    do: not is_nil(pid) and tm in ["partner_facilitated", "hybrid"]

  @doc "GraphQL `DistributionModelEnum` (atom)."
  def distribution_model(loan),
    do: if(partner_loan?(loan), do: :field_partner, else: :direct)

  # --- Images (privacy-gated: borrower photo only while fundraising) --------

  @doc """
  Resolved borrower image URL, or nil. Reuses the single source of truth for the
  privacy rule (`KivaWeb.Api.Serializer.borrower_image/2`): the photo is exposed
  only while the loan is still fundraising.
  """
  def image_url(%{status: status, borrower: %{image_url: url}}),
    do: KivaWeb.Api.Serializer.borrower_image(status, url)

  def image_url(_), do: nil

  @doc """
  Legacy `image` object `{id, template_id}`, or nil when no (visible) photo.
  The id is a stable pseudo-id derived from the URL so repeated calls match.
  """
  def legacy_image(loan) do
    case image_url(loan) do
      nil -> nil
      url -> %{id: :erlang.phash2(url, 1_000_000_000), template_id: 1}
    end
  end

  # --- Localized text ------------------------------------------------------

  @doc "Best display-eligible `*_lc` row for a locale (or nil), via the shared resolver."
  def resolve(translations, locale) when is_list(translations),
    do: Resolver.resolve_public(translations, locale).row

  def resolve(_, _), do: nil

  @doc "Locale codes a loan/partner is available in (display-eligible), sorted."
  def available_languages(translations) when is_list(translations) do
    translations
    |> Resolver.display_rows()
    |> Enum.map(& &1.locale_code)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def available_languages(_), do: []

  # --- Dates ---------------------------------------------------------------

  @doc "ISO-8601 UTC string with trailing Z (Kiva's date format), or nil."
  def iso8601(nil), do: nil
  def iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def iso8601(%Date{} = d), do: Date.to_iso8601(d)
  def iso8601(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt) <> "Z"

  # --- Geography -----------------------------------------------------------
  # We have no countries table; this static map covers the seeded countries plus
  # common Kiva markets. {name, region_code, lat, lng (country centroid)}.
  @countries %{
    "GT" => {"Guatemala", "ca", 15.78, -90.23},
    "KE" => {"Kenya", "af", -0.02, 37.91},
    "US" => {"United States", "na", 37.09, -95.71},
    "PE" => {"Peru", "sa", -9.19, -75.02},
    "PY" => {"Paraguay", "sa", -23.44, -58.44},
    "BO" => {"Bolivia", "sa", -16.29, -63.59},
    "EC" => {"Ecuador", "sa", -1.83, -78.18},
    "CO" => {"Colombia", "sa", 4.57, -74.30},
    "NI" => {"Nicaragua", "ca", 12.87, -85.21},
    "SV" => {"El Salvador", "ca", 13.79, -88.90},
    "HN" => {"Honduras", "ca", 15.20, -86.24},
    "MX" => {"Mexico", "ca", 23.63, -102.55},
    "PH" => {"Philippines", "as", 12.88, 121.77},
    "KH" => {"Cambodia", "as", 12.57, 104.99},
    "VN" => {"Vietnam", "as", 14.06, 108.28},
    "IN" => {"India", "as", 20.59, 78.96},
    "PK" => {"Pakistan", "as", 30.38, 69.35},
    "TJ" => {"Tajikistan", "as", 38.86, 71.28},
    "KG" => {"Kyrgyzstan", "as", 41.20, 74.77},
    "UG" => {"Uganda", "af", 1.37, 32.29},
    "RW" => {"Rwanda", "af", -1.94, 29.87},
    "TZ" => {"Tanzania", "af", -6.37, 34.89},
    "SN" => {"Senegal", "af", 14.50, -14.45},
    "NG" => {"Nigeria", "af", 9.08, 8.68},
    "GH" => {"Ghana", "af", 7.95, -1.02},
    "ML" => {"Mali", "af", 17.57, -3.99},
    "SL" => {"Sierra Leone", "af", 8.46, -11.78},
    "LB" => {"Lebanon", "me", 33.85, 35.86},
    "JO" => {"Jordan", "me", 30.59, 36.24},
    "PS" => {"Palestine", "me", 31.95, 35.23},
    "IL" => {"Israel", "me", 31.05, 34.85},
    "AM" => {"Armenia", "ee", 40.07, 45.04},
    "GE" => {"Georgia", "ee", 42.32, 43.36},
    "XK" => {"Kosovo", "ee", 42.60, 20.90},
    "UA" => {"Ukraine", "ee", 48.38, 31.17},
    "TR" => {"Turkey", "me", 38.96, 35.24}
  }

  @region_names %{
    "af" => "Africa",
    "as" => "Asia",
    "ca" => "Central America",
    "sa" => "South America",
    "na" => "North America",
    "me" => "Middle East",
    "ee" => "Eastern Europe",
    "we" => "Western Europe",
    "oc" => "Oceania"
  }

  @doc "Display country name for an ISO-2 code (falls back to the code itself)."
  def country_name(code) when is_binary(code) do
    case @countries[String.upcase(code)] do
      {name, _r, _lat, _lng} -> name
      nil -> code
    end
  end

  def country_name(_), do: nil

  @doc "Kiva 2-letter region code for an ISO-2 country code (or nil)."
  def region_code(code) when is_binary(code) do
    case @countries[String.upcase(code)] do
      {_n, region, _lat, _lng} -> region
      nil -> nil
    end
  end

  def region_code(_), do: nil

  @doc "Human region name (GraphQL `Country.region`) for an ISO-2 country code."
  def region_name(code), do: code |> region_code() |> then(&Map.get(@region_names, &1))

  @doc "All ISO-2 country codes belonging to a Kiva region code (e.g. \"af\")."
  def region_codes(region) when is_binary(region) do
    r = String.downcase(region)
    for {iso, {_n, reg, _lat, _lng}} <- @countries, reg == r, do: iso
  end

  def region_codes(_), do: []

  @doc """
  Legacy `location` object for a loan:
  `%{country_code, country, geo: %{level, pairs: "lat lng", type: "point"}}`.
  """
  def legacy_location(%{country_code: code}) do
    base = %{country_code: code, country: country_name(code)}

    case @countries[code && String.upcase(code)] do
      {_n, _r, lat, lng} ->
        Map.put(base, :geo, %{level: "country", pairs: "#{lat} #{lng}", type: "point"})

      _ ->
        base
    end
  end
end
