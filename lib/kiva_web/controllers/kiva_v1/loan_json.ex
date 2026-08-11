defmodule KivaWeb.KivaV1.LoanJSON do
  @moduledoc """
  Legacy Kiva REST v1 loan shaping. `summary/2` is the search/list shape;
  `detail/2` is the `/loans/:ids.json` superset (adds `description.texts`,
  `borrowers`, `terms`, `journal_totals`). Field names mirror the real API.
  """
  alias KivaWeb.KivaCompat.Mapping

  @doc "Summary loan object (search / newest / lenders' loans / team loans)."
  def summary(loan, ctx) do
    locale = ctx[:locale] || "en"
    lc = Mapping.resolve(loan.translations, locale)

    base = %{
      id: loan.id,
      name: name(loan, lc),
      description: %{languages: Mapping.available_languages(loan.translations)},
      status: Mapping.legacy_status(loan),
      funded_amount: Mapping.money_number(loan.funded_amount_cents),
      loan_amount: Mapping.money_number(loan.loan_amount_cents),
      activity: activity_name(loan, locale),
      sector: sector_name(loan, locale),
      themes: [],
      use: lc && lc.loan_use,
      location: Mapping.legacy_location(loan),
      partner_id: loan.partner_id,
      posted_date: Mapping.iso8601(loan.fundraising_started_at || loan.inserted_at),
      planned_expiration_date: Mapping.iso8601(loan.fundraising_ends_at),
      borrower_count: borrower_count(loan),
      lender_count: ctx[:lender_count] || 0,
      bonus_credit_eligibility: false,
      tags: []
    }

    base
    |> maybe_put(:image, Mapping.legacy_image(loan))
    |> maybe_put(:basket_amount, basket_amount(loan))
  end

  @doc "Detail loan object (`/loans/:ids.json`)."
  def detail(loan, ctx) do
    locale = ctx[:locale] || "en"

    loan
    |> summary(ctx)
    |> Map.update!(:description, fn d -> Map.put(d, :texts, texts(loan)) end)
    |> Map.merge(%{
      borrowers: borrowers(loan, locale),
      terms: terms(loan),
      journal_totals: %{entries: 0, bulkEntries: 0}
    })
    |> maybe_put(:funded_date, funded_date(loan))
  end

  # --- field helpers -------------------------------------------------------

  defp name(loan, lc), do: (lc && lc.title) || loan.slug

  defp sector_name(%{sector: %{} = s} = _loan, locale) do
    case Mapping.resolve(s.translations, locale) do
      %{name: n} when is_binary(n) -> n
      _ -> humanize(s.key)
    end
  end

  defp sector_name(_, _), do: nil

  defp activity_name(%{activity: %{} = a}, locale) do
    case Mapping.resolve(a.translations, locale) do
      %{name: n} when is_binary(n) -> n
      _ -> humanize(a.key)
    end
  end

  defp activity_name(_, _), do: nil

  defp borrower_count(%{borrower_id: nil}), do: 0
  defp borrower_count(_), do: 1

  defp basket_amount(%{status: "fundraising"}), do: 0
  defp basket_amount(_), do: nil

  defp texts(loan) do
    loan.translations
    |> Kiva.Localization.Resolver.display_rows()
    |> Map.new(fn lc -> {lc.locale_code, lc.borrower_story} end)
  end

  defp borrowers(%{borrower: %{} = b} = loan, locale) do
    blc = Mapping.resolve(b.translations, locale)
    {first, last} = split_name(blc && blc.display_name)

    [
      %{
        first_name: first,
        last_name: last,
        gender: Mapping.legacy_gender(b),
        pictured: not is_nil(Mapping.image_url(loan))
      }
    ]
  end

  defp borrowers(_, _), do: []

  defp terms(loan) do
    %{
      disbursal_date: Mapping.iso8601(loan.disbursed_at),
      disbursal_currency: loan.currency_code,
      disbursal_amount: Mapping.money_number(loan.loan_amount_cents),
      repayment_interval: humanize(loan.repayment_frequency),
      repayment_term: loan.repayment_term_months,
      loan_amount: Mapping.money_number(loan.loan_amount_cents),
      local_payments: [],
      scheduled_payments: scheduled_payments(loan),
      loss_liability: %{
        nonpayment: if(Mapping.partner_loan?(loan), do: "partner", else: "lender"),
        currency_exchange: "none",
        currency_exchange_coverage_rate: nil
      }
    }
  end

  defp scheduled_payments(%{repayment_schedule: %{items: items}}) when is_list(items) do
    items
    |> Enum.sort_by(& &1.due_on, Date)
    |> Enum.map(
      &%{due_date: Mapping.iso8601(&1.due_on), amount: Mapping.money_number(&1.amount_cents)}
    )
  end

  defp scheduled_payments(_), do: []

  defp funded_date(%{status: s, disbursed_at: at})
       when s in ["funded", "funded_disbursed", "repaying", "delinquent", "completed"],
       do: Mapping.iso8601(at)

  defp funded_date(_), do: nil

  defp split_name(nil), do: {nil, nil}

  defp split_name(full) do
    case String.split(full, " ", parts: 2) do
      [first, last] -> {first, last}
      [only] -> {only, nil}
    end
  end

  defp humanize(nil), do: nil

  defp humanize(key) when is_binary(key),
    do:
      key
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
