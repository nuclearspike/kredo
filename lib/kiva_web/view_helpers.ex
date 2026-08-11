defmodule KivaWeb.ViewHelpers do
  @moduledoc "Small presentation helpers shared across templates."

  @native_names %{
    "en" => "English",
    "de" => "Deutsch",
    "es" => "Español",
    "fr" => "Français",
    "nl" => "Nederlands"
  }

  @flags %{"en" => "🇬🇧", "de" => "🇩🇪", "es" => "🇪🇸", "fr" => "🇫🇷", "nl" => "🇳🇱"}

  def locale_native_name(code), do: Map.get(@native_names, code, code)
  def current_locale_name(code), do: locale_native_name(code)
  def locale_flag(code), do: Map.get(@flags, code, "🌐")
  def supported_locales, do: Kiva.Localization.supported_locales()

  @countries %{
    "GT" => "Guatemala",
    "KE" => "Kenya",
    "US" => "United States",
    "NL" => "Netherlands",
    "PE" => "Peru",
    "JO" => "Jordan",
    "UG" => "Uganda",
    "PH" => "Philippines",
    "KH" => "Cambodia",
    "NI" => "Nicaragua",
    "SN" => "Senegal",
    "VN" => "Vietnam",
    "BO" => "Bolivia",
    "EC" => "Ecuador",
    "RW" => "Rwanda",
    "TJ" => "Tajikistan"
  }
  def country_name(code), do: tr(Map.get(@countries, code, code))

  @country_flags %{
    "GT" => "🇬🇹",
    "KE" => "🇰🇪",
    "US" => "🇺🇸",
    "PE" => "🇵🇪",
    "JO" => "🇯🇴",
    "UG" => "🇺🇬",
    "NL" => "🇳🇱",
    "PH" => "🇵🇭",
    "KH" => "🇰🇭",
    "NI" => "🇳🇮",
    "SN" => "🇸🇳",
    "VN" => "🇻🇳",
    "BO" => "🇧🇴",
    "EC" => "🇪🇨",
    "RW" => "🇷🇼",
    "TJ" => "🇹🇯"
  }
  @doc "Flag emoji for a country code."
  def country_flag(code), do: Map.get(@country_flags, code, "🌍")

  @doc "Decorative placeholder pattern class for a loan card (by region)."
  def card_pattern(%{loan: %{country_code: cc}}), do: card_pattern(cc)
  def card_pattern(cc) when cc in ["GT", "JO"], do: "pat-gingham"
  def card_pattern("US"), do: "pat-waves"
  def card_pattern(_), do: "pat-dots"

  @doc "Locale-aware money formatting (delegates to the Localization context)."
  def money(cents, currency, locale),
    do: Kiva.Localization.format_money(cents || 0, currency || "USD", locale)

  @doc "Locale-aware thousands-grouped integer count."
  def num(n, locale), do: Kiva.Localization.format_count(n || 0, locale)

  @role_labels %{
    "lender" => "Lender",
    "borrower" => "Borrower",
    "partner" => "Partner",
    "staff" => "Staff",
    "admin" => "Admin",
    "public" => "Visitor"
  }
  @doc "Localized label for an actor role."
  def role_label(role), do: tr(Map.get(@role_labels, role, role))

  @months %{
    "en" => {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"},
    "es" => {"ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"},
    "de" => {"Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"},
    "fr" =>
      {"janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.",
       "déc."},
    "nl" => {"jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec"}
  }
  defp month_abbr(m, locale), do: @months |> Map.get(locale, @months["en"]) |> elem(m - 1)
  defp pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc "Locale-aware short date, e.g. \"Jun 12, 2026\" / \"12 jun 2026\"."
  def fmt_date(%DateTime{} = dt, locale),
    do: "#{month_abbr(dt.month, locale)} #{dt.day}, #{dt.year}"

  def fmt_date(_, _), do: ""

  @doc "Locale-aware date + 24h time (UTC)."
  def fmt_datetime(%DateTime{} = dt, locale),
    do: "#{fmt_date(dt, locale)} · #{pad2(dt.hour)}:#{pad2(dt.minute)}"

  def fmt_datetime(_, _), do: ""

  @doc "Locale-aware month + year, e.g. \"Mar 2024\"."
  def fmt_month(%DateTime{} = dt, locale), do: "#{month_abbr(dt.month, locale)} #{dt.year}"
  def fmt_month(_, _), do: ""

  @trust_labels %{
    "partner_facilitated" => "Partner-facilitated",
    "direct" => "Direct",
    "trustee_backed" => "Trustee-backed",
    "social_underwritten" => "Social underwriting",
    "blockchain_attested" => "Blockchain-attested",
    "hybrid" => "Hybrid"
  }
  def trust_model_label(tm), do: tr(Map.get(@trust_labels, tm, tm))

  @trust_explanations %{
    "partner_facilitated" =>
      "Managed by a local field partner who disburses funds and collects repayment.",
    "direct" => "Made directly to the borrower with social underwriting.",
    "trustee_backed" => "Backed by a community trustee who vouches for the borrower.",
    "social_underwritten" =>
      "Approved through community endorsements rather than formal credit history.",
    "blockchain_attested" => "Loan integrity recorded with a tamper-evident attestation.",
    "hybrid" => "Combines partner facilitation with community trust signals."
  }
  def trust_model_explanation(tm), do: tr(Map.get(@trust_explanations, tm, ""))

  @disbursal_labels %{
    "pre_disbursed" => "Pre-disbursed",
    "post_disbursed" => "Post-disbursed",
    "direct_disbursal_pending" => "Awaiting disbursal",
    "direct_disbursed" => "Disbursed"
  }
  def disbursal_label(d), do: tr(Map.get(@disbursal_labels, d, d))

  @doc "Localized label for an enum status value (humanizes underscores, then translates)."
  def status_label(s) when s in [nil, ""], do: ""
  def status_label(s), do: tr(s |> to_string() |> String.replace("_", " "))

  @doc "Friendly localized label for a loan lifecycle status (used on browse cards)."
  def loan_status_label("fundraising"), do: tr("Fundraising")
  def loan_status_label("funded"), do: tr("Funded")
  def loan_status_label("funded_disbursed"), do: tr("Funded")
  def loan_status_label("repaying"), do: tr("Repaying")
  def loan_status_label("completed"), do: tr("Repaid in full")
  def loan_status_label("delinquent"), do: tr("Behind on payments")
  def loan_status_label("defaulted"), do: tr("Defaulted")
  def loan_status_label("draft"), do: tr("Draft")
  def loan_status_label(s), do: status_label(s)

  @doc "DaisyUI tint classes for a loan-status badge."
  def loan_status_color("fundraising"), do: "bg-accent/15 text-accent"
  def loan_status_color("completed"), do: "bg-success/15 text-success"
  def loan_status_color("repaying"), do: "bg-info/15 text-info"
  def loan_status_color("funded"), do: "bg-primary/15 text-primary"
  def loan_status_color("funded_disbursed"), do: "bg-primary/15 text-primary"
  def loan_status_color("delinquent"), do: "bg-warning/20 text-warning"
  def loan_status_color("defaulted"), do: "bg-error/15 text-error"
  def loan_status_color(_), do: "bg-base-200 text-base-content/70"

  @doc "Localized notification title, derived from the notification type (language-neutral storage)."
  def notif_title(%{type: type} = n) do
    case type do
      "loan_funded" -> tr("Fully funded! 🎉")
      "disbursal" -> tr("Your loan reached the borrower 💸")
      "repayment" -> tr("Repayment received")
      "loan_outcome" -> tr("Outcome on a loan you supported 🌱")
      "borrower_update" -> tr("Update on a loan you supported")
      "loan_approved" -> tr("Your loan is live! 🎉")
      "changes_requested" -> tr("Changes requested on your loan")
      _ -> tr(Map.get(n, :title))
    end
  end

  @doc "Localized notification body. Static bodies translate; dynamic (user) content passes through."
  def notif_body(%{type: type} = n) do
    case type do
      "loan_funded" ->
        tr("A loan you supported is now fully funded.")

      "disbursal" ->
        tr("The funds you helped provide were disbursed.")

      "repayment" ->
        tr("A loan you supported received a repayment — your balance to relend grew.")

      "loan_approved" ->
        tr("Your loan was approved and is now fundraising.")

      _ ->
        tr(Map.get(n, :body))
    end
  end

  defp tr(s) when s in [nil, ""], do: ""
  defp tr(s) when is_binary(s), do: Gettext.gettext(KivaWeb.Gettext, s)
  defp tr(s), do: s

  @doc "Whole days until a fundraising deadline, or nil if past/unset."
  def days_left(nil), do: nil

  def days_left(%DateTime{} = ends_at) do
    case Date.diff(DateTime.to_date(ends_at), Date.utc_today()) do
      d when d >= 0 -> d
      _ -> nil
    end
  end

  def days_left(_), do: nil

  @doc "Static list of the four seeded demo accounts (for the home/login pages)."
  def demo_accounts do
    [
      %{role: "borrower", email: "borrower@kredo.test", locale: "es"},
      %{role: "lender", email: "lender@kredo.test", locale: "en"},
      %{role: "partner", email: "partner@kredo.test", locale: "es"},
      %{role: "admin", email: "admin@kredo.test", locale: "en"}
    ]
  end
end
