defmodule KivaWeb.KivaGraphql.LoanShape do
  @moduledoc """
  Shapes a raw `%Kiva.Lending.Loan{}` into the map the modern Kiva GraphQL schema
  resolves against (snake_case keys = Absinthe field identifiers, exposed camelCase).
  Money fields carry integer cents; the `:money` scalar renders the decimal string.
  `:distribution_model` drives the `LoanBasic` interface's `resolve_type`.
  """
  alias KivaWeb.KivaCompat.Mapping

  @doc "Shape one loan. `counts` is a `loan_id => lender_count` map."
  def to_map(loan, locale \\ "en", counts \\ %{}) do
    lc = Mapping.resolve(loan.translations, locale)
    dist = Mapping.distribution_model(loan)
    story = (lc && lc.borrower_story) || ""

    %{
      id: loan.id,
      name: (lc && lc.title) || loan.slug,
      full_name: (lc && lc.title) || loan.slug,
      use: lc && lc.loan_use,
      status: Mapping.gql_status(loan),
      status_label: Mapping.legacy_status(loan),
      loan_amount: loan.loan_amount_cents,
      paid_amount: 0,
      loan_fundraising_info: %{
        id: loan.id,
        funded_amount: loan.funded_amount_cents,
        reserved_amount: 0,
        is_expiring_soon: expiring_soon?(loan)
      },
      image: image(loan),
      geocode: geocode(loan),
      sector: sector(loan, locale),
      activity: activity(loan, locale),
      gender: Mapping.gql_gender(loan.borrower || %{}),
      borrower_count: borrower_count(loan),
      lender_count: Map.get(counts, loan.id, 0),
      borrowers: borrowers(loan, locale),
      description: story,
      description_in_original_language: story,
      distribution_model: dist,
      delinquent: Mapping.delinquent?(loan),
      anonymization_level: :none,
      repayment_interval: humanize(loan.repayment_frequency),
      lender_repayment_term: loan.repayment_term_months,
      tags: [],
      themes: [],
      disbursal_date: loan.disbursed_at,
      fundraising_date: loan.fundraising_started_at,
      planned_expiration_date: loan.fundraising_ends_at,
      raised_date: raised_date(loan),
      terms: terms(loan),
      # LoanPartner-specific
      partner_id: loan.partner_id,
      partner_name: partner_name(loan, locale),
      partner: partner(loan, locale),
      journal_count: 0,
      # LoanDirect-specific
      trustee_id: nil,
      trustee_name: nil,
      business_name: (lc && lc.title) || loan.slug,
      business_description: story,
      # interface bookkeeping for resolve_type
      _distribution: dist
    }
  end

  defp expiring_soon?(%{status: "fundraising", fundraising_ends_at: %DateTime{} = ends}),
    do: DateTime.diff(ends, DateTime.utc_now(), :day) <= 7

  defp expiring_soon?(_), do: false

  defp image(loan) do
    case Mapping.image_url(loan) do
      nil ->
        nil

      url ->
        %{id: :erlang.phash2(url, 1_000_000_000), url: url, hash: nil, width: nil, height: nil}
    end
  end

  defp geocode(%{country_code: code}) do
    region = Mapping.region_name(code)

    %{
      city: nil,
      state: nil,
      postal_code: nil,
      latitude: nil,
      longitude: nil,
      country: %{
        id: nil,
        name: Mapping.country_name(code),
        iso_code: code,
        region: region
      }
    }
  end

  defp sector(%{sector: %{} = s} = _l, locale) do
    name =
      case Mapping.resolve(s.translations, locale) do
        %{name: n} when is_binary(n) -> n
        _ -> humanize(s.key)
      end

    %{id: s.id, name: name}
  end

  defp sector(_, _), do: nil

  defp activity(%{activity: %{} = a}, locale) do
    name =
      case Mapping.resolve(a.translations, locale) do
        %{name: n} when is_binary(n) -> n
        _ -> humanize(a.key)
      end

    %{id: a.id, name: name}
  end

  defp activity(_, _), do: nil

  defp borrower_count(%{borrower_id: nil}), do: 0
  defp borrower_count(_), do: 1

  defp borrowers(%{borrower: %{} = b} = loan, locale) do
    blc = Mapping.resolve(b.translations, locale)
    {first, last} = split_name(blc && blc.display_name)

    [
      %{
        first_name: first,
        last_name: last,
        gender: Mapping.gql_gender(b),
        pictured: not is_nil(Mapping.image_url(loan))
      }
    ]
  end

  defp borrowers(_, _), do: []

  defp partner_name(%{partner: %{} = p} = _l, locale) do
    case Mapping.resolve(p.translations, locale) do
      %{name: n} when is_binary(n) -> n
      _ -> p.slug
    end
  end

  defp partner_name(_, _), do: nil

  defp partner(%{partner: %{} = p} = loan, locale),
    do: %{id: p.id, name: partner_name(loan, locale), status: p.status}

  defp partner(_, _), do: nil

  defp raised_date(%{status: s} = loan)
       when s in ["funded", "funded_disbursed", "repaying", "delinquent", "completed"],
       do: loan.disbursed_at || loan.updated_at

  defp raised_date(_), do: nil

  defp terms(loan) do
    %{
      currency: loan.currency_code,
      currency_full_name: nil,
      disbursal_amount: loan.loan_amount_cents,
      disbursal_date: loan.disbursed_at,
      loan_amount: loan.loan_amount_cents,
      lender_repayment_term: loan.repayment_term_months,
      loss_liability_nonpayment: if(Mapping.partner_loan?(loan), do: "partner", else: "lender"),
      loss_liability_currency_exchange: "none",
      expected_payments: expected_payments(loan)
    }
  end

  defp expected_payments(%{repayment_schedule: %{items: items}}) when is_list(items) do
    items
    |> Enum.sort_by(& &1.due_on, Date)
    |> Enum.map(&%{due_date: &1.due_on, amount: &1.amount_cents})
  end

  defp expected_payments(_), do: []

  defp split_name(nil), do: {nil, nil}

  defp split_name(full) do
    case String.split(full, " ", parts: 2) do
      [a, b] -> {a, b}
      [a] -> {a, nil}
    end
  end

  defp humanize(nil), do: nil

  defp humanize(k) when is_binary(k),
    do:
      k |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
end
