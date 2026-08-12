defmodule Kiva.Portfolio do
  @moduledoc "Lender fake-lending: records a lending and advances loan funding."
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Portfolio.Lend
  alias Kiva.Lending.{Loan, RepaymentSchedule, RepaymentScheduleItem}
  alias Kiva.Teams.Team
  alias Kiva.{Audit, Pagination}

  def lend(user, loan_id, amount_cents, team_id \\ nil) do
    # The loan row is locked for the whole read-decide-write: the last dollar and a
    # concurrent disbursal both decide the loan's next status from what they read,
    # and whichever ran on a stale copy would strand a funded, disbursed loan
    # outside repayment.
    {:ok, {lend, loan, crossed_to_funded?}} =
      Repo.transaction(fn ->
        loan = Repo.one!(from l in Loan, where: l.id == ^loan_id, lock: "FOR UPDATE")

        unless Loan.lendable?(loan) do
          raise ArgumentError,
                "cannot lend to loan #{loan.id} (#{loan.slug}): status #{loan.status} is not fundraising"
        end

        lend =
          %Lend{}
          |> Lend.changeset(%{
            user_id: uid(user),
            loan_id: loan_id,
            amount_cents: amount_cents,
            lending_team_id: team_id
          })
          |> Repo.insert!()

        new_funded = min(loan.loan_amount_cents, loan.funded_amount_cents + amount_cents)
        fully_funded? = new_funded >= loan.loan_amount_cents

        status =
          if fully_funded?,
            do: Kiva.Lending.status_on_full_funding(loan),
            else: loan.status

        loan
        |> Ecto.Changeset.change(funded_amount_cents: new_funded, status: status)
        |> Repo.update!()

        {lend, loan, fully_funded? and loan.funded_amount_cents < loan.loan_amount_cents}
      end)

    # Reveal: tell every lender of this loan when it crosses to fully funded.
    if crossed_to_funded? do
      Kiva.Notifications.notify_loan_lenders(
        loan_id,
        "loan_funded",
        "Fully funded! 🎉",
        "A loan you supported is now fully funded.",
        "/loans/#{loan.slug}"
      )
    end

    if team_id do
      case Repo.get(Team, team_id) do
        nil ->
          :ok

        team ->
          team
          |> Ecto.Changeset.change(total_lent_cents: team.total_lent_cents + amount_cents)
          |> Repo.update!()
      end
    end

    Audit.record(%{
      event_type: "loan.lent",
      actor_user_id: uid(user),
      target_type: "loan",
      target_id: to_string(loan_id),
      summary: "Lent #{amount_cents} cents",
      metadata: %{amount_cents: amount_cents}
    })

    lend
  end

  def list_user_lendings(user_id) do
    Repo.all(
      from l in Lend,
        where: l.user_id == ^user_id,
        order_by: [desc: l.inserted_at],
        preload: [loan: [:translations, repayment_schedule: :items]]
    )
  end

  @doc """
  A lender's lendings as localized summaries (loan title, status, amount). Used by
  the JSON/GraphQL `me` surfaces so serialization stays out of the web layer.
  """
  def list_user_lendings_localized(user_id, locale) do
    list_user_lendings(user_id)
    |> Enum.map(fn l ->
      %{
        loan_slug: l.loan.slug,
        loan_title: loan_title(l.loan, locale),
        status: l.loan.status,
        funded_percent: Kiva.Lending.funded_percent(l.loan),
        amount_cents: l.amount_cents,
        lending_team_id: l.lending_team_id,
        lent_at: l.inserted_at
      }
    end)
  end

  def portfolio_summary(user_id) do
    lendings = list_user_lendings(user_id)

    breakdown =
      Enum.map(lendings, fn l ->
        repaid = Kiva.Lending.loan_repaid_cents(l.loan)
        funded = max(l.loan.funded_amount_cents, 1)
        returned = min(l.amount_cents, round(repaid * l.amount_cents / funded))
        %{lending: l, returned_cents: returned}
      end)

    returned = Enum.sum(Enum.map(breakdown, & &1.returned_cents))

    %{
      count: length(lendings),
      total_cents: Enum.sum(Enum.map(lendings, & &1.amount_cents)),
      returned_cents: returned,
      available_to_relend_cents: returned,
      lendings: lendings,
      breakdown: breakdown
    }
  end

  @doc """
  Portfolio summary for a lender via SQL aggregates only (no row load) — totals,
  returns, and country/sector distribution. Stays cheap at any portfolio size.
  """
  def impact_summary(user_id, locale) do
    base = from(l in Lend, where: l.user_id == ^user_id)

    returned =
      Repo.one(
        from l in Lend,
          join: lo in Loan,
          on: lo.id == l.loan_id,
          left_join: rp in subquery(paid_sums()),
          on: rp.loan_id == lo.id,
          where: l.user_id == ^user_id,
          select:
            fragment(
              "COALESCE(SUM(LEAST(?, (COALESCE(?,0)::numeric * ? / GREATEST(?,1)))),0)::bigint",
              l.amount_cents,
              rp.repaid,
              l.amount_cents,
              lo.funded_amount_cents
            )
      ) || 0

    country_counts =
      Repo.all(
        from l in Lend,
          join: lo in Loan,
          on: lo.id == l.loan_id,
          where: l.user_id == ^user_id and not is_nil(lo.country_code),
          group_by: lo.country_code,
          select: {lo.country_code, count(l.id)}
      )
      |> Enum.map(fn {code, count} -> %{code: code, count: count} end)
      |> Enum.sort_by(&(-&1.count))

    borrower_count =
      Repo.one(
        from l in Lend,
          join: lo in Loan,
          on: lo.id == l.loan_id,
          where: l.user_id == ^user_id,
          select: count(lo.borrower_id, :distinct)
      ) || 0

    names = Map.new(Kiva.Taxonomy.list_sectors(locale), &{&1.id, &1.name})

    sectors =
      Repo.all(
        from l in Lend,
          join: lo in Loan,
          on: lo.id == l.loan_id,
          where: l.user_id == ^user_id,
          group_by: lo.sector_id,
          select: {lo.sector_id, count(l.id)}
      )
      |> Enum.map(fn {sid, c} -> %{id: sid, sector: Map.get(names, sid, "—"), count: c} end)
      |> Enum.sort_by(&(-&1.count))

    %{
      count: Repo.aggregate(base, :count, :id),
      total_cents: Repo.aggregate(base, :sum, :amount_cents) || 0,
      returned_cents: returned,
      available_to_relend_cents: returned,
      countries: Enum.map(country_counts, & &1.code),
      country_counts: country_counts,
      borrower_count: borrower_count,
      sectors: sectors
    }
  end

  @doc """
  One keyset page of the loans a lender has touched (limit+1 rows; caller chunks).
  Accepts the shared dimension filters (see `filter_lends/2`).
  """
  def impact_loans(user_id, locale, cursor, limit, filters \\ %{}) do
    from(l in Lend,
      join: lo in Loan,
      as: :loan,
      on: lo.id == l.loan_id,
      where: l.user_id == ^user_id,
      order_by: [desc: l.inserted_at, desc: l.id],
      limit: ^(limit + 1),
      preload: [
        loan: [
          :translations,
          [borrower: :translations],
          [sector: :translations],
          repayment_schedule: :items
        ]
      ]
    )
    |> filter_lends(filters)
    |> lend_keyset(Pagination.decode(cursor))
    |> Repo.all()
    |> Enum.map(fn l ->
      loan = l.loan
      funded = max(loan.funded_amount_cents, 1)
      repaid = Kiva.Lending.loan_repaid_cents(loan)

      %{
        slug: loan.slug,
        title: loan_title(loan, locale),
        borrower: borrower_display(loan, locale),
        country: loan.country_code,
        sector: Kiva.Taxonomy.name(loan.sector, locale),
        amount_cents: l.amount_cents,
        returned_cents: min(l.amount_cents, round(repaid * l.amount_cents / funded)),
        progress: Kiva.Lending.repayment_progress(loan),
        status: loan.status,
        cursor: Pagination.encode({l.inserted_at, l.id})
      }
    end)
  end

  @doc """
  Monthly scheduled vs received repayments (the lender's proportional share, in
  cents) across loans currently `repaying` or `delinquent` — the only statuses
  with money still in flight. Both series bucket by the installment's `due_on`
  month so that, for past months, scheduled minus received is exactly the
  behind-schedule amount. Dimension filters narrow the loan set; a `:status`
  filter is ignored here by design.
  """
  def expected_repayment_series(user_id, filters \\ %{}) do
    month = dynamic([item: i], fragment("date_trunc('month', ?)", i.due_on))

    from(l in Lend,
      join: lo in Loan,
      as: :loan,
      on: lo.id == l.loan_id,
      join: rs in RepaymentSchedule,
      on: rs.loan_id == lo.id,
      join: i in RepaymentScheduleItem,
      as: :item,
      on: i.repayment_schedule_id == rs.id,
      left_join: ss in subquery(sched_sums(user_id)),
      on: ss.loan_id == lo.id,
      where: l.user_id == ^user_id and lo.status in ["repaying", "delinquent"],
      group_by: ^month,
      order_by: ^month,
      select: %{
        month: type(fragment("date_trunc('month', ?)", i.due_on), :date),
        scheduled_cents:
          fragment(
            "COALESCE(SUM(?::numeric * ? / GREATEST(?, COALESCE(?,0), 1)),0)::bigint",
            i.amount_cents,
            l.amount_cents,
            lo.funded_amount_cents,
            ss.scheduled
          ),
        received_cents:
          fragment(
            "COALESCE(SUM(CASE WHEN ? = 'paid' THEN ?::numeric * ? / GREATEST(?, COALESCE(?,0), 1) ELSE 0 END),0)::bigint",
            i.status,
            i.amount_cents,
            l.amount_cents,
            lo.funded_amount_cents,
            ss.scheduled
          )
      }
    )
    |> filter_lends(Map.delete(filters, :status))
    |> Repo.all()
  end

  @doc """
  The lender-share amounts still unpaid on repaying/delinquent loans: due within
  the next 30 days, and already overdue. Powers the chart card's stat chips.
  """
  def late_and_upcoming(user_id, filters \\ %{}) do
    today = Date.utc_today()
    horizon = Date.add(today, 30)

    from(l in Lend,
      join: lo in Loan,
      as: :loan,
      on: lo.id == l.loan_id,
      join: rs in RepaymentSchedule,
      on: rs.loan_id == lo.id,
      join: i in RepaymentScheduleItem,
      as: :item,
      on: i.repayment_schedule_id == rs.id,
      left_join: ss in subquery(sched_sums(user_id)),
      on: ss.loan_id == lo.id,
      where:
        l.user_id == ^user_id and lo.status in ["repaying", "delinquent"] and i.status != "paid",
      select: %{
        upcoming_30_cents:
          fragment(
            "COALESCE(SUM(CASE WHEN ? >= ? AND ? <= ? THEN ?::numeric * ? / GREATEST(?, COALESCE(?,0), 1) ELSE 0 END),0)::bigint",
            i.due_on,
            ^today,
            i.due_on,
            ^horizon,
            i.amount_cents,
            l.amount_cents,
            lo.funded_amount_cents,
            ss.scheduled
          ),
        overdue_cents:
          fragment(
            "COALESCE(SUM(CASE WHEN ? < ? THEN ?::numeric * ? / GREATEST(?, COALESCE(?,0), 1) ELSE 0 END),0)::bigint",
            i.due_on,
            ^today,
            i.amount_cents,
            l.amount_cents,
            lo.funded_amount_cents,
            ss.scheduled
          )
      }
    )
    |> filter_lends(Map.delete(filters, :status))
    |> Repo.one() || %{upcoming_30_cents: 0, overdue_cents: 0}
  end

  @doc """
  Aggregate rollups of a lender's lendings along one dimension — `"country"`,
  `"status"`, `"sector"` or `"partner"` — within the current filters. Returns
  `%{key, label, count, lent_cents, returned_cents}` rows sorted by lent desc.
  A nil partner groups as `:direct` (direct/trustee loans have no field partner).
  """
  def impact_groups(user_id, locale, group_by, filters \\ %{})
      when group_by in ["country", "status", "sector", "partner"] do
    rows =
      from(l in Lend,
        join: lo in Loan,
        as: :loan,
        on: lo.id == l.loan_id,
        left_join: rp in subquery(paid_sums()),
        on: rp.loan_id == lo.id,
        where: l.user_id == ^user_id,
        select: %{
          count: count(l.id),
          lent_cents: coalesce(sum(l.amount_cents), 0),
          returned_cents:
            fragment(
              "COALESCE(SUM(LEAST(?, (COALESCE(?,0)::numeric * ? / GREATEST(?,1)))),0)::bigint",
              l.amount_cents,
              rp.repaid,
              l.amount_cents,
              lo.funded_amount_cents
            )
        }
      )
      |> filter_lends(filters)
      |> group_select(group_by)
      |> Repo.all()

    labels = group_labels(group_by, Enum.map(rows, & &1.key), locale)

    rows
    |> Enum.map(fn row ->
      key = if group_by == "partner" and is_nil(row.key), do: :direct, else: row.key
      %{row | key: key} |> Map.put(:label, Map.get(labels, key, to_string(key || "—")))
    end)
    |> Enum.sort_by(&{-&1.lent_cents, -&1.returned_cents})
  end

  # Ecto allows dynamics at the top level of group_by but not inside a select
  # tuple/map, so each dimension gets a literal group_by + select_merge clause.
  defp group_select(q, "country"),
    do:
      q
      |> group_by([loan: lo], lo.country_code)
      |> select_merge([loan: lo], %{key: lo.country_code})

  defp group_select(q, "status"),
    do: q |> group_by([loan: lo], lo.status) |> select_merge([loan: lo], %{key: lo.status})

  defp group_select(q, "sector"),
    do: q |> group_by([loan: lo], lo.sector_id) |> select_merge([loan: lo], %{key: lo.sector_id})

  defp group_select(q, "partner"),
    do:
      q |> group_by([loan: lo], lo.partner_id) |> select_merge([loan: lo], %{key: lo.partner_id})

  @doc "Slice totals for the active filters: lendings count, lent and returned cents."
  def filtered_totals(user_id, filters \\ %{}) do
    from(l in Lend,
      join: lo in Loan,
      as: :loan,
      on: lo.id == l.loan_id,
      left_join: rp in subquery(paid_sums()),
      on: rp.loan_id == lo.id,
      where: l.user_id == ^user_id,
      select: %{
        count: count(l.id),
        total_cents: coalesce(sum(l.amount_cents), 0),
        returned_cents:
          fragment(
            "COALESCE(SUM(LEAST(?, (COALESCE(?,0)::numeric * ? / GREATEST(?,1)))),0)::bigint",
            l.amount_cents,
            rp.repaid,
            l.amount_cents,
            lo.funded_amount_cents
          )
      }
    )
    |> filter_lends(filters)
    |> Repo.one() || %{count: 0, total_cents: 0, returned_cents: 0}
  end

  @doc """
  Options for the slice-and-dice filter controls, scoped to what this lender's
  portfolio actually contains: statuses and partners with counts (partners
  resolve localized names; a nil partner surfaces as `:direct` when present).
  """
  def filter_facets(user_id, locale) do
    statuses =
      Repo.all(
        from l in Lend,
          join: lo in Loan,
          on: lo.id == l.loan_id,
          where: l.user_id == ^user_id,
          group_by: lo.status,
          select: {lo.status, count(l.id)}
      )
      |> Enum.map(fn {s, c} -> %{key: s, count: c} end)
      |> Enum.sort_by(&(-&1.count))

    partner_rows =
      Repo.all(
        from l in Lend,
          join: lo in Loan,
          on: lo.id == l.loan_id,
          where: l.user_id == ^user_id,
          group_by: lo.partner_id,
          select: {lo.partner_id, count(l.id)}
      )

    names = group_labels("partner", Enum.map(partner_rows, &elem(&1, 0)), locale)

    partners =
      partner_rows
      |> Enum.map(fn {id, c} ->
        key = if is_nil(id), do: :direct, else: id
        %{key: key, name: Map.get(names, key, "—"), count: c}
      end)
      |> Enum.sort_by(&(-&1.count))

    %{statuses: statuses, partners: partners}
  end

  @doc """
  Shared dimension filters for a lender's lendings. Recognized keys:
  `:status`, `:country`, `:sector_id`, `:partner_id` (integer or `:direct`).
  Queries must bind the joined loan under the `:loan` named binding.
  """
  def filter_lends(query, filters) do
    Enum.reduce(filters || %{}, query, fn
      {:status, s}, q when is_binary(s) -> where(q, [loan: lo], lo.status == ^s)
      {:country, c}, q when is_binary(c) -> where(q, [loan: lo], lo.country_code == ^c)
      {:sector_id, id}, q when is_integer(id) -> where(q, [loan: lo], lo.sector_id == ^id)
      {:partner_id, :direct}, q -> where(q, [loan: lo], is_nil(lo.partner_id))
      {:partner_id, id}, q when is_integer(id) -> where(q, [loan: lo], lo.partner_id == ^id)
      _, q -> q
    end)
  end

  defp group_labels("country", _keys, _locale), do: %{}
  defp group_labels("status", _keys, _locale), do: %{}

  defp group_labels("sector", _keys, locale),
    do: Map.new(Kiva.Taxonomy.list_sectors(locale), &{&1.id, &1.name})

  defp group_labels("partner", keys, locale) do
    ids = keys |> Enum.reject(&(&1 in [nil, :direct]))

    Repo.all(
      from p in Kiva.Partners.Partner,
        where: p.id in ^ids,
        preload: :translations
    )
    |> Map.new(fn p ->
      name =
        case Kiva.Localization.Resolver.resolve_public(p.translations, locale).row do
          nil -> p.slug
          row -> row.name
        end

      {p.id, name}
    end)
  end

  # Total scheduled across a loan's installments, for one lender's loans only.
  #
  # A borrower's schedule can total more than the loan principal, because the
  # field partner charges the borrower interest and fees. None of that overage
  # belongs to the lender: lending here returns principal at best (0% to the
  # lender), so a lender's share of an installment divides by the LARGER of the
  # funded principal and the scheduled total. That keeps their cumulative
  # receipts at or below what they lent. Dividing by funded principal alone
  # projects a profit that cannot exist.
  #
  # The `loan_id in (this lender's loans)` filter is load-bearing, not cosmetic:
  # without it the aggregate scans every schedule item in the database before
  # the join narrows it to one portfolio.
  defp sched_sums(user_id) do
    mine = from(l in Lend, where: l.user_id == ^user_id, select: l.loan_id)

    from i in RepaymentScheduleItem,
      join: rs in RepaymentSchedule,
      on: rs.id == i.repayment_schedule_id,
      where: rs.loan_id in subquery(mine),
      group_by: rs.loan_id,
      select: %{loan_id: rs.loan_id, scheduled: sum(i.amount_cents)}
  end

  defp paid_sums do
    from i in RepaymentScheduleItem,
      join: rs in RepaymentSchedule,
      on: rs.id == i.repayment_schedule_id,
      where: i.status == "paid",
      group_by: rs.loan_id,
      select: %{loan_id: rs.loan_id, repaid: sum(i.amount_cents)}
  end

  defp lend_keyset(q, nil), do: q

  defp lend_keyset(q, {ts, id}),
    do: where(q, [l], l.inserted_at < ^ts or (l.inserted_at == ^ts and l.id < ^id))

  defp loan_title(loan, locale) do
    case Kiva.Localization.Resolver.resolve_public(loan.translations, locale).row do
      nil -> loan.slug
      row -> row.title
    end
  end

  defp borrower_display(%{borrower: b}, locale) when not is_nil(b) do
    case Kiva.Localization.Resolver.resolve_public(b.translations, locale).row do
      nil -> b.public_id
      row -> row.display_name
    end
  end

  defp borrower_display(_, _), do: nil

  defp uid(%{id: id}), do: id
  defp uid(_), do: nil
end
