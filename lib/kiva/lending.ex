defmodule Kiva.Lending do
  @moduledoc """
  Loan lifecycle reads for public/lender surfaces. Returns localized loan cards
  and profiles (canonical numeric truth + resolved `*_lc` text + fallback flags).
  This is the context behind `localizedLoanSearch` / `localizedLoanProfile`.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.Taxonomy
  alias Kiva.Lending.{Loan, LoanLc, RepaymentSchedule, RepaymentScheduleItem}
  alias Kiva.Audit
  require Logger

  @public_statuses ~w(fundraising funded funded_disbursed repaying completed)

  @doc """
  Localized loan search. `filters` may include `:sector_id`, `:country_code`,
  `:trust_model`, and `:q` (free-text over the resolved title/story).
  """
  def list_localized_loans(locale, filters \\ %{}) do
    Loan
    |> where([l], l.status in ^status_set(filters[:status]))
    |> filter_sector(filters[:sector_id])
    |> filter_country(filters[:country_code])
    |> filter_trust(filters[:trust_model])
    |> search_loans(filters[:q], locale)
    |> keyset_before(Kiva.Pagination.decode(filters[:cursor]))
    |> order_by([l], desc: l.inserted_at, desc: l.id)
    |> limit(^(Kiva.Pagination.page_limit(filters) + 1))
    |> preload(
      ^[
        :translations,
        [partner: :translations],
        [sector: :translations],
        [activity: :translations],
        [borrower: :translations]
      ]
    )
    |> Repo.all()
    |> then(fn loans ->
      counts = lender_counts(Enum.map(loans, & &1.id))
      Enum.map(loans, &localize_card(&1, locale, counts))
    end)
  end

  @doc """
  Loan counts per browse status-filter value, honoring the sector/country/trust/search
  filters (but not status). One GROUP BY — cheap even at 100K.
  """
  def status_counts(locale, filters \\ %{}) do
    rows =
      Loan
      |> filter_sector(filters[:sector_id])
      |> filter_country(filters[:country_code])
      |> filter_trust(filters[:trust_model])
      |> search_loans(filters[:q], locale)
      |> group_by([l], l.status)
      |> select([l], {l.status, count(l.id)})
      |> Repo.all()
      |> Map.new()

    sum = fn statuses -> statuses |> Enum.map(&Map.get(rows, &1, 0)) |> Enum.sum() end

    %{
      "fundraising" => sum.(["fundraising"]),
      "repaying" => sum.(["repaying", "funded", "funded_disbursed"]),
      "completed" => sum.(["completed"]),
      "delinquent" => sum.(["delinquent"]),
      "defaulted" => sum.(["defaulted"]),
      "all" => sum.(@public_statuses ++ ["delinquent", "defaulted"])
    }
  end

  @doc "Aggregate stats for the browse hero — SQL count/sum, no row load."
  def browse_stats(filters \\ %{}) do
    base = from(l in Loan, where: l.status in ^status_set(filters[:status]))

    %{
      count: Repo.aggregate(base, :count, :id),
      raised_cents: Repo.aggregate(base, :sum, :funded_amount_cents) || 0
    }
  end

  defp keyset_before(query, nil), do: query

  defp keyset_before(query, {ts, id}),
    do: where(query, [l], l.inserted_at < ^ts or (l.inserted_at == ^ts and l.id < ^id))

  # Matches where a WORD STARTS with the term (`\m` is Postgres's start-of-word
  # escape), in the one translation the reader is actually shown.
  #
  # Two things it deliberately does not do.
  #
  # It does not match a term buried inside a longer word: someone typing their
  # way to "catering" passes through "cat", and a plain `ILIKE '%cat%'` hands
  # them every education loan, because "education" contains those letters.
  #
  # It does not search translations the reader cannot see, which would return
  # cards whose visible text contains none of the searched words. Which row the
  # reader sees is `Resolver`'s rule, mirrored here in SQL: the requested locale
  # when it has a display-eligible row, otherwise the English fallback.
  #
  # A single character starts a word in nearly every loan, so it is treated as
  # no filter rather than as a search for everything.
  defp search_loans(query, q, locale) when is_binary(q) do
    term = String.trim(q)

    if String.length(term) < 2 do
      query
    else
      pattern = "\\m" <> escape_regex(term)
      locale = Kiva.Localization.normalize(locale)
      statuses = Resolver.display_statuses()

      where(
        query,
        [l],
        fragment(
          """
          EXISTS (
            SELECT 1 FROM loans_lc lc
            WHERE lc.loan_id = ?
              AND lc.translation_status = ANY(?)
              AND (lc.title ~* ? OR lc.short_description ~* ? OR lc.borrower_story ~* ?)
              AND (
                lc.locale_code = ?
                OR (
                  lc.locale_code = 'en'
                  AND NOT EXISTS (
                    SELECT 1 FROM loans_lc alt
                    WHERE alt.loan_id = lc.loan_id
                      AND alt.locale_code = ?
                      AND alt.translation_status = ANY(?)
                  )
                )
              )
          )
          """,
          l.id,
          ^statuses,
          ^pattern,
          ^pattern,
          ^pattern,
          ^locale,
          ^locale,
          ^statuses
        )
      )
    end
  end

  defp search_loans(query, _q, _locale), do: query

  # The search term becomes part of a regular expression, so neutralise the
  # operators a searcher may reasonably type ("co-op (2024)", "35+").
  defp escape_regex(term),
    do: Regex.replace(~r/[.^$*+?()\[\]{}|\\]/, term, fn m -> "\\" <> m end)

  # Which loan statuses a browse query returns. Default = active/lendable public set;
  # an explicit filter can surface a single state (incl. delinquent/defaulted, which
  # are not in the default set), or "all" for everything except drafts.
  defp status_set(nil), do: @public_statuses
  defp status_set("fundraising"), do: ["fundraising"]
  defp status_set("repaying"), do: ["repaying", "funded", "funded_disbursed"]
  defp status_set("completed"), do: ["completed"]
  defp status_set("delinquent"), do: ["delinquent"]
  defp status_set("defaulted"), do: ["defaulted"]
  defp status_set("all"), do: @public_statuses ++ ["delinquent", "defaulted"]
  defp status_set(other) when is_binary(other), do: [other]

  @doc "Number of distinct lendings recorded against a loan (social proof)."
  def lender_count(loan_id) do
    Repo.aggregate(from(l in Kiva.Portfolio.Lend, where: l.loan_id == ^loan_id), :count)
  end

  defp lender_counts([]), do: %{}

  defp lender_counts(loan_ids) do
    Repo.all(
      from l in Kiva.Portfolio.Lend,
        where: l.loan_id in ^loan_ids,
        group_by: l.loan_id,
        select: {l.loan_id, count(l.id)}
    )
    |> Map.new()
  end

  @doc "Public batch lender-count map for loan ids (used by the Kiva-compat layer)."
  def lender_count_map(loan_ids), do: lender_counts(loan_ids)

  # --- Kiva-compatibility queries -----------------------------------------
  # These return RAW `%Loan{}` structs (with the standard preloads) plus a total,
  # so the compat REST views and GraphQL resolvers can shape exact Kiva fields.
  # All filters are already in our native vocabulary (the web layer translates
  # Kiva's params via `KivaWeb.KivaCompat.Mapping` before calling in).

  @kiva_preloads [
    :translations,
    [partner: :translations],
    [sector: :translations],
    [activity: :translations],
    [borrower: :translations],
    [repayment_schedule: :items]
  ]

  @doc "Preload list the compat serializers expect on a loan."
  def kiva_preloads, do: @kiva_preloads

  @doc """
  Kiva-style loan search. `opts` (all optional):
  `:statuses` (list of our status strings; default = public set), `:gender`
  ("male"/"female"), `:sector` (id or key string), `:country_codes` (list, already
  region-expanded), `:partner_ids` (list), `:q`, `:sort_by` (Kiva sort name),
  `:limit`, `:offset`. Returns `{loans, total}`.
  """
  def kiva_search(opts \\ %{}) do
    statuses = opts[:statuses] || @public_statuses ++ ["delinquent", "defaulted"]
    limit = opts[:limit] || 20
    offset = opts[:offset] || 0

    base =
      Loan
      |> where([l], l.status in ^statuses)
      |> kiva_filter_sector(opts[:sector])
      |> kiva_filter_countries(opts[:country_codes])
      |> kiva_filter_partners(opts[:partner_ids])
      |> kiva_filter_gender(opts[:gender])
      |> search_loans(opts[:q], opts[:locale] || "en")

    total = Repo.aggregate(base, :count, :id)

    loans =
      base
      |> kiva_order(opts[:sort_by])
      |> limit(^limit)
      |> offset(^offset)
      |> preload(^@kiva_preloads)
      |> Repo.all()

    {loans, total}
  end

  @doc "Loans by id, preloaded for compat detail views, ordered to match `ids`."
  def kiva_loans_by_ids([], _), do: []

  def kiva_loans_by_ids(ids, _locale) do
    by_id =
      Loan
      |> where([l], l.id in ^ids)
      |> preload(^@kiva_preloads)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.flat_map(ids, fn id -> if l = by_id[id], do: [l], else: [] end)
  end

  @doc "One loan by id with compat preloads, or nil."
  def kiva_get_loan(id) do
    Loan |> where([l], l.id == ^id) |> preload(^@kiva_preloads) |> Repo.one()
  end

  @doc """
  Lenders who funded a loan, newest first: `[{user_or_nil, amount_cents}]`.
  Anonymous (user_id nil) lendings come back as `{nil, amount}`.
  """
  def kiva_loan_lenders(loan_id, limit, offset) do
    q =
      from l in Kiva.Portfolio.Lend,
        where: l.loan_id == ^loan_id,
        order_by: [desc: l.inserted_at, desc: l.id],
        limit: ^limit,
        offset: ^offset,
        left_join: u in Kiva.Accounts.User,
        on: u.id == l.user_id,
        select: {u, l.amount_cents}

    rows = Repo.all(q)
    total = Repo.aggregate(from(l in Kiva.Portfolio.Lend, where: l.loan_id == ^loan_id), :count)
    {rows, total}
  end

  defp kiva_filter_sector(q, nil), do: q
  defp kiva_filter_sector(q, ""), do: q

  defp kiva_filter_sector(q, val) when is_integer(val), do: where(q, [l], l.sector_id == ^val)

  defp kiva_filter_sector(q, val) when is_binary(val) do
    case Integer.parse(val) do
      {id, ""} ->
        where(q, [l], l.sector_id == ^id)

      _ ->
        key = String.downcase(val)
        from l in q, join: s in assoc(l, :sector), where: fragment("lower(?)", s.key) == ^key
    end
  end

  defp kiva_filter_countries(q, nil), do: q
  defp kiva_filter_countries(q, []), do: q

  defp kiva_filter_countries(q, codes) when is_list(codes) do
    upper = Enum.map(codes, &String.upcase/1)
    where(q, [l], l.country_code in ^upper)
  end

  defp kiva_filter_partners(q, nil), do: q
  defp kiva_filter_partners(q, []), do: q
  defp kiva_filter_partners(q, ids) when is_list(ids), do: where(q, [l], l.partner_id in ^ids)

  defp kiva_filter_gender(q, g) when g in ["male", "female", "nonbinary"] do
    from l in q, join: b in assoc(l, :borrower), where: b.gender == ^g
  end

  defp kiva_filter_gender(q, _), do: q

  defp kiva_order(q, "oldest"), do: order_by(q, [l], asc: l.inserted_at, asc: l.id)
  defp kiva_order(q, "loan_amount"), do: order_by(q, [l], desc: l.loan_amount_cents, desc: l.id)

  defp kiva_order(q, "repayment_term"),
    do: order_by(q, [l], asc: l.repayment_term_months, asc: l.id)

  defp kiva_order(q, "expiration"), do: order_by(q, [l], asc: l.fundraising_ends_at, asc: l.id)
  defp kiva_order(q, "popularity"), do: order_by(q, [l], desc: l.funded_amount_cents, desc: l.id)

  defp kiva_order(q, "amount_remaining"),
    do:
      order_by(q, [l],
        desc: fragment("? - ?", l.loan_amount_cents, l.funded_amount_cents),
        desc: l.id
      )

  defp kiva_order(q, "random"), do: order_by(q, fragment("RANDOM()"))
  defp kiva_order(q, _newest), do: order_by(q, [l], desc: l.inserted_at, desc: l.id)

  @doc "Distinct loans a lender (user) has funded, newest funding first: `{loans, total}`."
  def kiva_lender_loans(user_id, limit, offset),
    do: kiva_loans_via_lendings([user_id: user_id], limit, offset)

  @doc "Distinct loans funded through a team: `{loans, total}`."
  def kiva_team_loans(team_id, limit, offset),
    do: kiva_loans_via_lendings([lending_team_id: team_id], limit, offset)

  defp kiva_loans_via_lendings(where_clause, limit, offset) do
    ids_q =
      from l in Kiva.Portfolio.Lend,
        where: ^where_clause,
        group_by: l.loan_id,
        select: %{loan_id: l.loan_id, last: max(l.inserted_at)}

    total = Repo.aggregate(from(r in subquery(ids_q)), :count)

    page =
      from(r in subquery(ids_q), order_by: [desc: r.last], limit: ^limit, offset: ^offset)
      |> Repo.all()

    ordered_ids = Enum.map(page, & &1.loan_id)
    loans = kiva_loans_by_ids(ordered_ids, nil)
    {loans, total}
  end

  @doc "Count of distinct loans a lender has funded (Kiva lender `loan_count`)."
  def kiva_lender_loan_count(user_id) do
    Repo.aggregate(
      from(l in Kiva.Portfolio.Lend, where: l.user_id == ^user_id, distinct: l.loan_id),
      :count,
      :loan_id
    )
  end

  def get_localized_loan(slug, locale) do
    loan =
      Loan
      |> where(slug: ^slug)
      |> preload(
        ^[
          :translations,
          [partner: :translations],
          [sector: :translations],
          [activity: :translations],
          [borrower: :translations],
          [repayment_schedule: :items]
        ]
      )
      |> Repo.one()

    loan && localize_profile(loan, locale)
  end

  @doc "A borrower's own loans (localized profiles, excluding drafts)."
  def list_loans_for_borrower(borrower_id, locale) do
    Loan
    |> where([l], l.borrower_id == ^borrower_id and l.status != "draft")
    |> order_by([l], desc: l.inserted_at)
    |> preload(
      ^[
        :translations,
        [partner: :translations],
        [sector: :translations],
        [activity: :translations],
        [borrower: :translations],
        [repayment_schedule: :items]
      ]
    )
    |> Repo.all()
    |> Enum.map(&localize_profile(&1, locale))
  end

  @doc """
  Demo time-machine: advance every active loan one lifecycle step
  (fund → disburse → repay → complete), firing the cross-actor reveals so the
  whole demo (lender balances, partner dashboard, notifications) visibly moves.
  Returns a frequency map, e.g. %{funded: 1, disbursed: 1, repaid: 2}.
  """
  def advance_demo_time do
    Loan
    |> where([l], l.status in ["fundraising", "funded", "repaying"])
    |> preload(repayment_schedule: :items)
    |> Repo.all()
    |> Enum.map(&advance_one/1)
    |> Enum.frequencies()
  end

  defp advance_one(loan) do
    cond do
      loan.funded_amount_cents < loan.loan_amount_cents ->
        simulate_funding(loan)
        :funded

      is_nil(loan.disbursed_at) ->
        record_disbursal(loan.id)
        :disbursed

      next_scheduled?(loan) ->
        record_repayment(loan.id)
        :repaid

      true ->
        :none
    end
  end

  defp simulate_funding(loan) do
    # Same lock as a real lend: this decides the loan's status from what it reads,
    # and the preloaded struct it was handed may already be stale.
    Repo.transaction(fn ->
      locked = Repo.one!(from l in Loan, where: l.id == ^loan.id, lock: "FOR UPDATE")

      locked
      |> Ecto.Changeset.change(
        funded_amount_cents: locked.loan_amount_cents,
        status: status_on_full_funding(locked)
      )
      |> Repo.update!()
    end)

    Kiva.Notifications.notify_loan_lenders(
      loan.id,
      "loan_funded",
      "Fully funded! 🎉",
      "A loan you supported is now fully funded.",
      "/loans/#{loan.slug}"
    )
  end

  defp next_scheduled?(%{repayment_schedule: %{items: items}}) when is_list(items),
    do: Enum.any?(items, &(&1.status == "scheduled"))

  defp next_scheduled?(_), do: false

  @doc """
  The status a loan takes when its last dollar is lent.

  A loan the partner already disbursed goes straight into repayment; one still
  awaiting disbursal waits at funded. The already-disbursed case has to check for
  a schedule of its own rather than trusting disbursal to have left one, because a
  loan disbursed before schedules were created at disbursal still has none.
  """
  def status_on_full_funding(%Loan{} = loan) do
    cond do
      not enters_repayment?(loan) -> loan.status
      is_nil(loan.disbursed_at) -> "funded"
      ensure_repayment_schedule(loan) == :no_term -> "funded"
      true -> "repaying"
    end
  end

  # A loan enters repayment once it is disbursed, fully funded, and holds the
  # schedule it will repay against. A field partner may disburse while the crowd
  # is still lending (disbursal_status direct_disbursal_pending), and that loan
  # must stay fundraising so the remaining lenders can still reach it —
  # Portfolio.lend/4 moves it on when the last dollar lands. Only fundraising and
  # funded advance: a retry against an already completed or defaulted loan leaves
  # it where it is rather than walking its lifecycle backwards.
  defp status_after_disbursal(%Loan{} = loan, scheduling) do
    fully_funded? = loan.funded_amount_cents >= loan.loan_amount_cents

    if enters_repayment?(loan) and fully_funded? and
         scheduling in [:scheduled, :already_scheduled] do
      "repaying"
    else
      loan.status
    end
  end

  # The only statuses from which a loan may enter repayment. A completed,
  # defaulted or delinquent loan stays where it is: a repeated disbursal or a
  # stray lend must not walk its lifecycle backwards, or hand it fresh
  # obligations it has already discharged.
  defp enters_repayment?(%Loan{status: status}), do: status in ["fundraising", "funded"]

  @doc """
  Give a loan the repayment schedule it owes, if it has none.

  Returns `:already_scheduled`, `:scheduled`, or `:no_term`. Idempotent — a loan
  that already has a schedule (every seeded loan does) keeps it untouched. Callers
  must not move a loan into repayment on `:no_term`: a loan with no term cannot be
  given a schedule, and a repaying loan without one can never complete.

  Call this inside a transaction holding the loan row; the check-then-insert is
  only safe against a concurrent disbursal while that lock is held.
  """
  def ensure_repayment_schedule(%Loan{} = loan) do
    cond do
      Repo.exists?(from s in RepaymentSchedule, where: s.loan_id == ^loan.id) ->
        :already_scheduled

      is_nil(loan.repayment_term_months) or loan.repayment_term_months < 1 ->
        Logger.warning(
          "loan #{loan.id} disbursed with no repayment term; it has no repayment schedule and cannot repay"
        )

        :no_term

      true ->
        # Repayments are anchored to the disbursal, so a loan whose funds went out
        # earlier gets the due dates it should have had, not dates counted from
        # whenever the schedule happened to be written.
        starts_on =
          if loan.disbursed_at, do: DateTime.to_date(loan.disbursed_at), else: Date.utc_today()

        create_principal_repayment_schedule(
          loan.id,
          starts_on,
          loan.repayment_term_months,
          loan.loan_amount_cents
        )

        :scheduled
    end
  end

  @doc """
  Record that a loan's funds reached the borrower (a partner/staff action).
  Advances `disbursal_status`, stamps `disbursed_at`, and reveals to lenders.
  """
  def record_disbursal(loan_id) do
    # One transaction with the loan row locked: a second disbursal of the same
    # loan waits here rather than racing ensure_repayment_schedule/1 into a
    # duplicate schedule, and a failure anywhere rolls the whole step back
    # instead of leaving a repaying loan with a half-written schedule.
    {:ok, {loan, outcome}} =
      Repo.transaction(fn ->
        loan = Repo.one!(from l in Loan, where: l.id == ^loan_id, lock: "FOR UPDATE")

        if loan.disbursed_at do
          # Money only leaves once. A repeat call keeps the original disbursal
          # date and status rather than restamping them, so a retry cannot turn a
          # direct disbursal into a post-disbursal or re-date a schedule already
          # anchored to the first one.
          {loan, :already_disbursed}
        else
          # A loan past repayment is not given a fresh set of obligations by a
          # late disbursal.
          scheduling =
            if enters_repayment?(loan), do: ensure_repayment_schedule(loan), else: :closed

          new_status =
            case loan.disbursal_status do
              "direct_disbursal_pending" -> "direct_disbursed"
              _ -> "post_disbursed"
            end

          loan =
            loan
            |> Ecto.Changeset.change(
              disbursal_status: new_status,
              status: status_after_disbursal(loan, scheduling),
              disbursed_at: DateTime.utc_now() |> DateTime.truncate(:second)
            )
            |> Repo.update!()

          {loan, :disbursed}
        end
      end)

    # Only a disbursal that actually happened is recorded and revealed — a repeat
    # call must not tell every lender their money moved a second time.
    if outcome == :disbursed do
      Audit.record(%{
        event_type: "loan.disbursed",
        target_type: "loan",
        target_id: to_string(loan_id),
        summary: "Loan ##{loan_id} disbursed (#{loan.disbursal_status})"
      })

      Kiva.Notifications.notify_loan_lenders(
        loan_id,
        "disbursal",
        "Your loan reached the borrower 💸",
        "The funds you helped provide were disbursed.",
        "/loans/#{loan.slug}"
      )
    end

    loan
  end

  @doc """
  Cheap dashboard aggregates for a partner: loan counts, total funded, and the
  number of loans with a repayment still due. Computed with SQL aggregates (no
  row loading or localization) so it stays fast for partners with very large
  portfolios. The actual due loans live on their own paged page — see
  `partner_repayments_due/2`.
  """
  def partner_overview(partner_id) do
    stats =
      Repo.one(
        from l in Loan,
          where: l.partner_id == ^partner_id and l.status != "draft",
          select: %{
            count: count(l.id),
            total_funded_cents: coalesce(sum(l.funded_amount_cents), 0),
            live_count: filter(count(l.id), l.status == "fundraising")
          }
      )

    Map.put(stats, :repayments_due_count, repayments_due_count(partner_id))
  end

  defp repayments_due_count(partner_id) do
    Repo.one(
      from l in Loan,
        join: s in RepaymentSchedule,
        on: s.loan_id == l.id,
        join: i in RepaymentScheduleItem,
        on: i.repayment_schedule_id == s.id and i.status == "scheduled",
        where: l.partner_id == ^partner_id and l.status in ["funded", "repaying"],
        select: count(l.id, :distinct)
    ) || 0
  end

  @repayments_per_page 25

  @doc """
  One page of a partner's loans that still have a repayment due, ordered by the
  soonest scheduled installment. Options: `:q` (search borrower name / loan
  title / slug), `:page` (1-based), `:per_page`, `:locale`. Only the page's rows
  are loaded and localized, so it stays fast at any portfolio size.

  Returns `%{rows, page, per_page, total, pages, q}`.
  """
  def partner_repayments_due(partner_id, opts \\ %{}) do
    page = max(opts[:page] || 1, 1)
    per = opts[:per_page] || @repayments_per_page
    locale = opts[:locale] || "en"
    q = opts[:q]

    filtered = search_due(due_base(partner_id), q)

    total = Repo.one(from([loan: l] in filtered, select: count(l.id, :distinct))) || 0

    ordered_ids =
      filtered
      |> group_by([loan: l], l.id)
      |> select([loan: l, item: i], %{id: l.id, next_due: min(i.due_on)})
      |> order_by([item: i], asc: min(i.due_on))
      |> order_by([loan: l], asc: l.id)
      |> limit(^per)
      |> offset(^((page - 1) * per))
      |> Repo.all()
      |> Enum.map(& &1.id)

    %{
      rows: load_due_profiles(ordered_ids, locale),
      page: page,
      per_page: per,
      total: total,
      pages: ceil_div(total, per),
      q: q || ""
    }
  end

  # Loans (funded/repaying) that still have a scheduled installment. Named
  # bindings (:loan, :item) let `search_due/2` add joins without breaking refs.
  defp due_base(partner_id) do
    from l in Loan,
      as: :loan,
      join: s in RepaymentSchedule,
      on: s.loan_id == l.id,
      join: i in RepaymentScheduleItem,
      as: :item,
      on: i.repayment_schedule_id == s.id and i.status == "scheduled",
      where: l.partner_id == ^partner_id and l.status in ["funded", "repaying"]
  end

  defp search_due(query, q) when is_binary(q) and q != "" do
    like = "%#{q}%"

    from [loan: l] in query,
      left_join: llc in LoanLc,
      on: llc.loan_id == l.id,
      left_join: b in assoc(l, :borrower),
      left_join: blc in Kiva.Borrowers.BorrowerLc,
      on: blc.borrower_id == b.id,
      where:
        ilike(l.slug, ^like) or ilike(llc.title, ^like) or
          ilike(blc.display_name, ^like) or ilike(b.public_id, ^like)
  end

  defp search_due(query, _), do: query

  defp load_due_profiles([], _locale), do: []

  defp load_due_profiles(ids, locale) do
    by_id =
      Loan
      |> where([l], l.id in ^ids)
      |> preload(
        ^[
          :translations,
          [partner: :translations],
          [sector: :translations],
          [activity: :translations],
          [borrower: :translations],
          [repayment_schedule: :items]
        ]
      )
      |> Repo.all()
      |> Enum.map(&localize_profile(&1, locale))
      |> Map.new(&{&1.loan.id, &1})

    ids |> Enum.map(&Map.get(by_id, &1)) |> Enum.reject(&is_nil/1)
  end

  defp ceil_div(_total, per) when per <= 0, do: 0
  defp ceil_div(total, per), do: div(total + per - 1, per)

  @doc "Loans awaiting staff review (for the admin queue)."
  def review_queue(locale) do
    Loan
    |> where([l], l.status in ["submitted_to_staff", "staff_review"])
    |> order_by([l], desc: l.updated_at)
    |> preload(
      ^[
        :translations,
        [partner: :translations],
        [sector: :translations],
        [activity: :translations],
        [borrower: :translations]
      ]
    )
    |> Repo.all()
    |> Enum.map(fn loan ->
      loan |> localize_card(locale) |> Map.put(:detail, review_detail(loan, locale))
    end)
  end

  @doc """
  The full picture a reviewer needs before approving a listing: localized content,
  per-locale translation coverage, and a list of missing fields. Powers the
  expandable review card in AdminLive (so staff approve with eyes open, not blind).
  """
  def review_detail(%Loan{} = loan, locale) do
    row = Resolver.resolve_public(loan.translations, locale).row

    %{
      story: row && row.borrower_story,
      loan_use: row && row.loan_use,
      risk_summary: row && row.risk_summary_public,
      repayment_summary: row && row.repayment_summary,
      translations: translation_coverage(loan.translations),
      missing: review_missing(loan, row)
    }
  end

  defp translation_coverage(translations) do
    translations
    |> Enum.map(
      &%{locale: &1.locale_code, status: &1.translation_status, is_source: &1.is_source}
    )
    |> Enum.sort_by(& &1.locale)
  end

  defp review_missing(loan, row) do
    [
      {blank?(row && row.borrower_story), "borrower story"},
      {blank?(row && row.risk_summary_public), "risk summary"},
      {blank?(row && row.loan_use), "loan use"},
      {is_nil(loan.repayment_term_months), "repayment term"}
    ]
    |> Enum.filter(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp blank?(nil), do: true
  defp blank?(s) when is_binary(s), do: String.trim(s) == ""
  defp blank?(_), do: false

  @doc """
  Locales a loan is not yet publishable in: any supported locale with no
  language-content row, or whose translation has not been reviewed.

  The source row is exempt from the review bar because it is the original, not
  a translation; its own text is what listing review approves. Returns
  `{:error, :loan_not_found}` for an unknown loan.
  """
  @reviewed_translation_statuses ~w(approved published)

  def untranslated_locales(loan_id) do
    if Repo.exists?(from l in Loan, where: l.id == ^loan_id) do
      ready =
        from(lc in LoanLc,
          where: lc.loan_id == ^loan_id,
          select: {lc.locale_code, lc.is_source, lc.translation_status}
        )
        |> Repo.all()
        |> Enum.filter(fn {_code, is_source, status} ->
          is_source or status in @reviewed_translation_statuses
        end)
        |> MapSet.new(fn {code, _, _} -> code end)

      Enum.reject(Kiva.Localization.supported_locales(), &MapSet.member?(ready, &1))
    else
      {:error, :loan_not_found}
    end
  end

  @doc """
  Publishes a reviewed listing.

  Refuses while any supported language is still missing or unreviewed: a loan
  that goes live in one language reaches lenders who cannot read it, and the
  borrower's story is what they are being asked to back. The command layer
  gates this too; the check lives here as well so no caller can publish around
  it.
  """
  def approve_listing(loan_id, actor \\ nil) do
    case untranslated_locales(loan_id) do
      [] -> publish_reviewed_listing(loan_id, actor)
      {:error, reason} -> {:error, reason}
      pending -> {:error, {:translations_pending, pending}}
    end
  end

  defp publish_reviewed_listing(loan_id, actor) do
    loan = Repo.get!(Loan, loan_id)
    loan = loan |> Ecto.Changeset.change(status: "fundraising") |> Repo.update!()

    # Listing review approves the source text, so it stops being a draft.
    from(lc in LoanLc,
      where: lc.loan_id == ^loan.id and lc.is_source and lc.translation_status == "draft"
    )
    |> Repo.update_all(
      set: [
        translation_status: "published",
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      ]
    )

    Audit.record(%{
      event_type: "loan.listing_approved",
      target_type: "loan",
      target_id: to_string(loan_id),
      summary: "Loan ##{loan_id} approved and published"
    })

    Kiva.Provenance.record_side_effect(%{
      loan_id: loan.id,
      subject_type: "listing",
      subject_ref: "loan:#{loan.id}",
      event_type: "listing.approved",
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:second),
      actor_kind: "human",
      actor_name: (actor && (actor.display_name || actor.email)) || "Staff reviewer",
      actor_role: (actor && actor.role) || "staff",
      actor_user_id: actor && actor.id,
      visibility: "admin",
      details: %{status: "fundraising"}
    })

    # Reveal to the partner: their submitted loan is now live.
    Kiva.Notifications.notify_partner(
      loan,
      "loan_approved",
      "Your loan is live! 🎉",
      "Your loan was approved and is now fundraising.",
      "/loans/#{loan.slug}"
    )

    {:ok, loan}
  end

  def request_changes(loan_id, reason \\ nil) do
    loan = Repo.get!(Loan, loan_id)

    loan =
      loan
      |> Ecto.Changeset.change(status: "changes_requested", changes_requested_reason: reason)
      |> Repo.update!()

    Audit.record(%{
      event_type: "loan.changes_requested",
      target_type: "loan",
      target_id: to_string(loan_id),
      summary: "Changes requested on loan ##{loan_id}",
      metadata: %{reason: reason}
    })

    # Reveal to the partner: what to fix, and how to resume.
    Kiva.Notifications.notify_partner(
      loan,
      "changes_requested",
      "Changes requested on your loan",
      reason || "Staff requested changes before this loan can be published.",
      "/partner"
    )

    loan
  end

  @doc "Count of loans awaiting staff review (powers the staff GraphQL field)."
  def review_queue_count do
    Repo.aggregate(
      from(l in Loan, where: l.status in ["submitted_to_staff", "staff_review", "under_review"]),
      :count
    )
  end

  def funded_percent(%Loan{loan_amount_cents: 0}), do: 0

  def funded_percent(%Loan{loan_amount_cents: amt, funded_amount_cents: funded}) do
    min(100, round(funded / amt * 100))
  end

  # --- Repayment loop (closes lender → fund → repay → relend) ---------

  @doc """
  Record the next scheduled repayment on a loan (a partner/staff action — the
  partner remits what the borrower repaid). Advances the schedule and, when the
  last item is paid, marks the loan `completed`.
  """
  def record_repayment(loan_id) do
    loan = Repo.get!(Loan, loan_id) |> Repo.preload(repayment_schedule: :items)
    schedule = loan.repayment_schedule

    next_item =
      schedule &&
        schedule.items
        |> Enum.sort_by(& &1.due_on, Date)
        |> Enum.find(&(&1.status == "scheduled"))

    cond do
      is_nil(schedule) ->
        {:error, :no_schedule}

      is_nil(next_item) ->
        {:error, :fully_repaid}

      true ->
        item =
          next_item
          |> Ecto.Changeset.change(status: "paid", paid_on: Date.utc_today())
          |> Repo.update!()

        if Enum.count(schedule.items, &(&1.status == "scheduled")) - 1 <= 0 do
          loan |> Ecto.Changeset.change(status: "completed") |> Repo.update!()
        end

        Audit.record(%{
          event_type: "loan.repayment_recorded",
          target_type: "loan",
          target_id: to_string(loan_id),
          summary: "Repayment of #{item.amount_cents} cents recorded on loan ##{loan_id}",
          metadata: %{amount_cents: item.amount_cents}
        })

        # Reveal: tell every lender of this loan their balance grew.
        Kiva.Notifications.notify_loan_lenders(
          loan_id,
          "repayment",
          "Repayment received",
          "A loan you supported received a repayment — your balance to relend grew.",
          "/portfolio"
        )

        {:ok, item}
    end
  end

  @doc "Total repaid cents for a loan (sum of paid schedule items)."
  def loan_repaid_cents(%Loan{repayment_schedule: %{items: items}}) when is_list(items) do
    items |> Enum.filter(&(&1.status == "paid")) |> Enum.map(& &1.amount_cents) |> Enum.sum()
  end

  def loan_repaid_cents(%Loan{id: loan_id}) do
    Repo.aggregate(
      from(i in RepaymentScheduleItem,
        join: s in RepaymentSchedule,
        on: s.id == i.repayment_schedule_id,
        where: s.loan_id == ^loan_id and i.status == "paid"
      ),
      :sum,
      :amount_cents
    ) || 0
  end

  @doc "Repayment progress summary for a loan with its schedule loaded."
  def repayment_progress(%Loan{repayment_schedule: %{items: items}}) when is_list(items) do
    paid = Enum.filter(items, &(&1.status == "paid"))

    %{
      paid_count: length(paid),
      total_count: length(items),
      paid_cents: paid |> Enum.map(& &1.amount_cents) |> Enum.sum(),
      total_cents: items |> Enum.map(& &1.amount_cents) |> Enum.sum()
    }
  end

  def repayment_progress(_), do: %{paid_count: 0, total_count: 0, paid_cents: 0, total_cents: 0}

  defp filter_sector(q, nil), do: q
  defp filter_sector(q, ""), do: q
  defp filter_sector(q, id), do: where(q, [l], l.sector_id == ^id)
  defp filter_country(q, nil), do: q
  defp filter_country(q, ""), do: q
  defp filter_country(q, code), do: where(q, [l], l.country_code == ^code)
  defp filter_trust(q, nil), do: q
  defp filter_trust(q, ""), do: q
  defp filter_trust(q, tm), do: where(q, [l], l.trust_model == ^tm)

  defp localize_card(%Loan{} = loan, locale, counts \\ %{}) do
    res = Resolver.resolve_public(loan.translations, locale)

    %{
      loan: loan,
      lc: res.row,
      resolved_locale: res.locale,
      fallback_used: res.fallback_used,
      title: (res.row && res.row.title) || loan.slug,
      short_description: res.row && res.row.short_description,
      borrower_name: borrower_name(loan.borrower, locale),
      partner_name: partner_name(loan.partner, locale),
      sector_name: Taxonomy.name(loan.sector, locale),
      activity_name: Taxonomy.name(loan.activity, locale),
      borrower_image: borrower_image(loan.borrower),
      funded_percent: funded_percent(loan),
      lenders_count: Map.get(counts, loan.id, 0)
    }
  end

  defp borrower_image(%{image_url: url}), do: url
  defp borrower_image(_), do: nil

  defp localize_profile(%Loan{} = loan, locale) do
    card = localize_card(loan, locale, %{loan.id => lender_count(loan.id)})

    Map.merge(card, %{
      borrower_story: card.lc && card.lc.borrower_story,
      loan_use: card.lc && card.lc.loan_use,
      repayment_summary: card.lc && card.lc.repayment_summary,
      risk_summary_public: card.lc && card.lc.risk_summary_public,
      schedule: loan.repayment_schedule,
      repayment: repayment_progress(loan)
    })
  end

  defp borrower_name(%{translations: trs}, locale) when is_list(trs) do
    case Resolver.resolve_public(trs, locale).row do
      nil -> nil
      row -> row.display_name
    end
  end

  defp borrower_name(_, _), do: nil

  defp partner_name(%{translations: trs, slug: slug}, locale) when is_list(trs) do
    case Resolver.resolve_public(trs, locale).row do
      nil -> slug
      row -> row.name
    end
  end

  defp partner_name(_, _), do: nil

  # --- Authoring helpers (seeds) ---
  def upsert_loan(attrs) do
    Repo.insert!(struct(Loan, attrs),
      on_conflict:
        {:replace,
         [
           :status,
           :loan_amount_cents,
           :funded_amount_cents,
           :trust_model,
           :disbursal_status,
           :country_code,
           :sector_id,
           :activity_id,
           :partner_id,
           :borrower_id,
           :repayment_term_months
         ]},
      conflict_target: :slug
    )

    Repo.get_by!(Loan, slug: attrs.slug)
  end

  def upsert_loan_lc(attrs),
    do:
      %LoanLc{}
      |> LoanLc.changeset(attrs)
      |> Repo.insert!(
        on_conflict:
          {:replace,
           [
             :title,
             :short_description,
             :borrower_story,
             :loan_use,
             :repayment_summary,
             :risk_summary_public,
             :translation_status
           ]},
        conflict_target: [:loan_id, :locale_code, :version]
      )

  @doc """
  A monthly schedule whose items sum to exactly `total_cents`.

  The division remainder is spread one cent at a time across the earliest items
  rather than dropped or piled onto the last one. It does not take a flat
  per-month amount like `create_repayment_schedule/4` does, because a lender's
  expected-repayment total is summed from these rows: a term that does not
  divide the principal evenly would otherwise schedule more or less than the
  borrower actually owes.
  """
  def create_principal_repayment_schedule(loan_id, starts_on, term_months, total_cents)
      when is_integer(term_months) and term_months >= 1 and is_integer(total_cents) and
             total_cents >= 0 do
    # The schedule and every one of its items land together or not at all. A
    # partially written schedule would look complete to ensure_repayment_schedule/1
    # forever after, since that only checks whether a schedule row exists.
    {:ok, schedule} =
      Repo.transaction(fn ->
        schedule =
          Repo.insert!(%RepaymentSchedule{
            loan_id: loan_id,
            starts_on: starts_on,
            term_months: term_months,
            frequency: "monthly"
          })

        base = div(total_cents, term_months)
        remainder = rem(total_cents, term_months)

        for m <- 1..term_months do
          Repo.insert!(%RepaymentScheduleItem{
            repayment_schedule_id: schedule.id,
            due_on: Date.add(starts_on, 30 * m),
            amount_cents: base + if(m <= remainder, do: 1, else: 0),
            status: "scheduled"
          })
        end

        schedule
      end)

    schedule
  end

  @doc """
  A monthly schedule of `term_months` items of `monthly_cents` each.

  Used by the seeds and fixtures, where the per-month figure is the given
  quantity. When what you have is a principal to divide, use
  `create_principal_repayment_schedule/4` instead — the items here total
  `term_months * monthly_cents`, which need not equal the loan amount.
  """
  def create_repayment_schedule(loan_id, starts_on, term_months, monthly_cents) do
    schedule =
      Repo.insert!(%RepaymentSchedule{
        loan_id: loan_id,
        starts_on: starts_on,
        term_months: term_months,
        frequency: "monthly"
      })

    for m <- 1..term_months do
      Repo.insert!(%RepaymentScheduleItem{
        repayment_schedule_id: schedule.id,
        due_on: Date.add(starts_on, 30 * m),
        amount_cents: monthly_cents,
        status: "scheduled"
      })
    end

    schedule
  end
end
