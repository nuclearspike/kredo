defmodule KivaWeb.PortfolioLive do
  @moduledoc """
  The lender's impact page: hero summary, cumulative repayment chart for loans
  still paying back, slice-and-dice (filter + group by country/status/sector/
  partner, URL-backed), distribution facets, and the loans touched.
  """
  use KivaWeb, :live_view

  alias Kiva.Portfolio

  # Repaid-progress ring: 2πr with r=70 in a 160×160 viewBox.
  @ring_circumference 439.82

  # Chart geometry (viewBox units).
  @cw 720
  @ch 240
  @ml 46
  @mr 12
  @mt 14
  @mb 24

  @statuses ~w(fundraising funded funded_disbursed repaying delinquent completed defaulted)
  @group_dims ~w(country status sector partner)

  def mount(_params, _session, socket) do
    uid = socket.assigns.current_user.id
    summary = Portfolio.impact_summary(uid, socket.assigns.locale)

    {:ok,
     assign(socket,
       page_title: gettext("My impact"),
       summary: summary,
       facets: Portfolio.filter_facets(uid, socket.assigns.locale),
       repaid_pct: repaid_percent(summary),
       max_sector: max_sector_count(summary.sectors)
     )}
  end

  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)
    group_by = if params["group"] in @group_dims, do: params["group"]

    {:noreply,
     socket
     |> assign(filters: filters, group_by: group_by, cursor: nil, cursor_stack: [])
     |> load_slice()}
  end

  def handle_event("filter", params, socket) do
    patch_slice(socket, %{
      "status" => params["status"],
      "country" => params["country"],
      "sector" => params["sector"],
      "partner" => params["partner"],
      "group" => socket.assigns.group_by
    })
  end

  def handle_event("set_group", %{"group" => g}, socket) do
    patch_slice(socket, filter_params(socket.assigns.filters, (g != "" && g) || nil))
  end

  def handle_event("clear_filters", _, socket) do
    patch_slice(socket, %{"group" => socket.assigns.group_by})
  end

  def handle_event("facet", %{"dim" => dim, "key" => key}, socket) do
    filters = toggle_filter(socket.assigns.filters, dim, key)
    patch_slice(socket, filter_params(filters, socket.assigns.group_by))
  end

  def handle_event("drill", %{"dim" => dim, "key" => key}, socket) do
    filters = set_filter(socket.assigns.filters, dim, key)
    patch_slice(socket, filter_params(filters, nil))
  end

  def handle_event("next", _, socket) do
    {:noreply,
     socket
     |> assign(
       cursor_stack: [socket.assigns.cursor | socket.assigns.cursor_stack],
       cursor: socket.assigns.next_cursor
     )
     |> assign_loans()}
  end

  def handle_event("prev", _, socket) do
    case socket.assigns.cursor_stack do
      [prev | rest] ->
        {:noreply, socket |> assign(cursor: prev, cursor_stack: rest) |> assign_loans()}

      [] ->
        {:noreply, socket}
    end
  end

  # —— slice loading ——

  defp load_slice(socket) do
    uid = socket.assigns.current_user.id
    filters = socket.assigns.filters
    series = Portfolio.expected_repayment_series(uid, filters)

    socket
    |> assign(
      chart: build_chart(series, socket.assigns.locale),
      flow: Portfolio.late_and_upcoming(uid, filters),
      totals: if(filters != %{}, do: Portfolio.filtered_totals(uid, filters)),
      groups:
        if(socket.assigns.group_by,
          do:
            Portfolio.impact_groups(uid, socket.assigns.locale, socket.assigns.group_by, filters)
        )
    )
    |> assign_loans()
  end

  defp assign_loans(%{assigns: %{group_by: g}} = socket) when not is_nil(g),
    do: assign(socket, loans: [], next_cursor: nil)

  defp assign_loans(socket) do
    lim = Kiva.Pagination.default_limit()

    rows =
      Portfolio.impact_loans(
        socket.assigns.current_user.id,
        socket.assigns.locale,
        socket.assigns.cursor,
        lim,
        socket.assigns.filters
      )

    page = Enum.take(rows, lim)
    next = if length(rows) > lim, do: List.last(page).cursor, else: nil
    assign(socket, loans: page, next_cursor: next)
  end

  defp patch_slice(socket, params) do
    query = params |> Enum.reject(fn {_, v} -> v in [nil, ""] end) |> Map.new()
    {:noreply, push_patch(socket, to: ~p"/portfolio?#{query}")}
  end

  # —— filter params ——

  defp parse_filters(params) do
    country = if is_binary(params["country"]), do: String.upcase(params["country"]), else: nil

    %{}
    |> maybe_put(:status, params["status"] in @statuses && params["status"])
    |> maybe_put(:country, is_binary(country) and country =~ ~r/^[A-Z]{2}$/ and country)
    |> maybe_put(:sector_id, parse_int(params["sector"]))
    |> maybe_put(:partner_id, parse_partner(params["partner"]))
  end

  defp maybe_put(map, _k, v) when v in [nil, false], do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp parse_int(nil), do: nil

  defp parse_int(s) do
    case Integer.parse(to_string(s)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_partner("direct"), do: :direct
  defp parse_partner(v), do: parse_int(v)

  defp filter_params(filters, group) do
    %{
      "status" => filters[:status],
      "country" => filters[:country],
      "sector" => filters[:sector_id],
      "partner" => encode_partner(filters[:partner_id]),
      "group" => group
    }
  end

  defp encode_partner(:direct), do: "direct"
  defp encode_partner(v), do: v

  @dim_keys %{
    "status" => :status,
    "country" => :country,
    "sector" => :sector_id,
    "partner" => :partner_id
  }

  defp toggle_filter(filters, dim, key) do
    {fkey, value} = dim_value(dim, key)

    if filters[fkey] == value,
      do: Map.delete(filters, fkey),
      else: maybe_put(filters, fkey, value)
  end

  defp set_filter(filters, dim, key) do
    {fkey, value} = dim_value(dim, key)
    maybe_put(filters, fkey, value)
  end

  defp dim_value(dim, key) do
    fkey = Map.fetch!(@dim_keys, dim)

    value =
      case fkey do
        :sector_id -> parse_int(key)
        :partner_id -> parse_partner(key)
        _ -> key
      end

    {fkey, value}
  end

  # —— hero helpers ——

  defp repaid_percent(%{total_cents: total}) when total in [0, nil], do: 0

  defp repaid_percent(%{total_cents: total, returned_cents: returned}),
    do: returned |> Kernel.*(100) |> Kernel./(total) |> round() |> max(0) |> min(100)

  defp max_sector_count([%{count: top} | _]), do: top
  defp max_sector_count([]), do: 0

  defp bar_width(_count, max) when max in [0, nil], do: 0.0
  defp bar_width(count, max), do: Float.round(count * 100 / max, 1)

  defp ring_offset(percent), do: Float.round(@ring_circumference * (100 - percent) / 100, 2)
  defp ring_circumference, do: @ring_circumference

  # —— chart math ——

  defp build_chart([], _locale), do: nil

  defp build_chart(rows, locale) do
    n = length(rows)
    today = Date.utc_today()
    this_month = Date.beginning_of_month(today)

    {cum, {sched_total, _}} =
      Enum.map_reduce(rows, {0, 0}, fn r, {s, v} ->
        s2 = s + r.scheduled_cents
        v2 = v + r.received_cents
        {%{month: r.month, sched: s2, recv: v2}, {s2, v2}}
      end)

    nice = nice_max(sched_total)
    pw = @cw - @ml - @mr
    ph = @ch - @mt - @mb
    x = fn i -> Float.round(@ml + i * pw / max(n - 1, 1), 1) end
    y = fn v -> Float.round(@mt + ph - v * ph / nice, 1) end

    points =
      cum
      |> Enum.with_index()
      |> Enum.map(fn {p, i} ->
        %{
          i: i,
          x: x.(i),
          y_s: y.(p.sched),
          y_r: y.(p.recv),
          month: p.month,
          label: month_label(p.month, locale),
          sched_str: money(p.sched, "USD", locale),
          recv_str: money(p.recv, "USD", locale),
          show_recv: Date.compare(p.month, this_month) != :gt,
          flip: i > n * 0.62
        }
      end)

    recv_pts = Enum.filter(points, & &1.show_recv)
    baseline = @mt + ph

    %{
      n: n,
      col_w: Float.round(pw / max(n - 1, 1), 1),
      points: points,
      sched_path: Enum.map_join(points, " ", &"#{&1.x},#{&1.y_s}"),
      recv_path: Enum.map_join(recv_pts, " ", &"#{&1.x},#{&1.y_r}"),
      recv_area: recv_area(recv_pts, baseline),
      recv_end: List.last(recv_pts),
      sched_end: List.last(points),
      end_label: axis_money(sched_total, locale),
      ticks:
        for q <- [0.25, 0.5, 0.75, 1.0] do
          %{y: y.(round(nice * q)), label: axis_money(round(nice * q), locale)}
        end,
      x_labels:
        for p <- points, rem(p.i, max(1, ceil(n / 6))) == 0 do
          %{x: p.x, label: p.label}
        end,
      today_x: today_x(points, today, x),
      baseline: baseline
    }
  end

  defp recv_area([], _baseline), do: nil

  defp recv_area(pts, baseline) do
    first = List.first(pts)
    last = List.last(pts)

    "#{first.x},#{baseline} " <>
      Enum.map_join(pts, " ", &"#{&1.x},#{&1.y_r}") <> " #{last.x},#{baseline}"
  end

  defp today_x(points, today, x) do
    this_month = Date.beginning_of_month(today)

    case Enum.find_index(points, &(Date.compare(&1.month, this_month) == :eq)) do
      nil ->
        nil

      i ->
        frac = (today.day - 1) / Date.days_in_month(today)

        Float.round(
          min(
            x.(i) + frac * (x.(min(i + 1, length(points) - 1)) - x.(i)),
            x.(length(points) - 1)
          ),
          1
        )
    end
  end

  # Smallest {1,2,4,5,8,10}×10^k dollars ≥ max, in cents — keeps quarter-ticks clean.
  defp nice_max(cents) when cents <= 0, do: 100

  defp nice_max(cents) do
    dollars = cents / 100
    k = max(floor(:math.log10(dollars)), 0)
    base = :math.pow(10, k)

    mult = Enum.find([1, 2, 4, 5, 8, 10], 10, fn m -> m * base >= dollars end)
    round(mult * base) * 100
  end

  defp month_label(%Date{} = d, locale),
    do: fmt_month(DateTime.new!(d, ~T[00:00:00], "Etc/UTC"), locale)

  # Compact axis money: "$1.3k" / "14k $" — exact values live in tooltips + table.
  defp axis_money(cents, locale) do
    dollars = cents / 100
    dec = if locale == "en", do: ".", else: ","

    compact =
      cond do
        dollars >= 1_000_000 -> compact_num(dollars / 1_000_000, dec) <> "M"
        dollars >= 1_000 -> compact_num(dollars / 1_000, dec) <> "k"
        true -> nil
      end

    cond do
      is_nil(compact) -> money(round(dollars) * 100, "USD", locale)
      locale == "en" -> "$" <> compact
      true -> compact <> " $"
    end
  end

  defp compact_num(v, dec) do
    :erlang.float_to_binary(Float.round(v * 1.0, 1), decimals: 1)
    |> String.replace(".", dec)
    |> String.replace_suffix(dec <> "0", "")
  end

  # —— chip / option labels ——

  defp sector_name(summary, id),
    do: Enum.find_value(summary.sectors, to_string(id), fn s -> s.id == id && s.sector end)

  defp partner_name(facets, key),
    do: Enum.find_value(facets.partners, "—", fn p -> p.key == key && p.name end)

  defp chip_label(:status, v, _summary, _facets), do: loan_status_label(v)
  defp chip_label(:country, v, _summary, _facets), do: "#{country_flag(v)} #{country_name(v)}"
  defp chip_label(:sector_id, v, summary, _facets), do: sector_name(summary, v)
  defp chip_label(:partner_id, :direct, _summary, _facets), do: trust_model_label("direct")
  defp chip_label(:partner_id, v, _summary, facets), do: partner_name(facets, v)

  defp group_title("country", g), do: country_name(g.key)
  defp group_title(_dim, g), do: g.label

  @chip_dims %{status: "status", country: "country", sector_id: "sector", partner_id: "partner"}
  defp chip_dim(fkey), do: Map.fetch!(@chip_dims, fkey)
  defp chip_key(:direct), do: "direct"
  defp chip_key(v), do: to_string(v)

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="portfolio"
    >
      <%!-- Empty portfolio: a warm invitation instead of a dashboard of zeros. --%>
      <div :if={@summary.count == 0}>
        <div class="flex items-center gap-3">
          <img
            :if={@current_user.avatar_url}
            src={@current_user.avatar_url}
            alt=""
            class="size-12 rounded-full object-cover"
          />
          <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
            {gettext("My impact")}
          </h1>
        </div>
        <section class="rounded-3xl border border-base-200 bg-base-200/70 mt-6">
          <div class="px-6 py-16 text-center max-w-md mx-auto">
            <div class="mx-auto grid size-14 place-items-center rounded-full bg-primary/15 text-primary">
              <.icon name="hero-heart" class="size-7" />
            </div>
            <h2 class="font-display text-2xl font-semibold text-secondary mt-4">
              {gettext("Your impact starts here")}
            </h2>
            <p class="text-base-content/70 mt-2">
              {gettext("You haven't lent yet. Find a borrower to support.")}
            </p>
            <.link navigate={~p"/loans"} class="btn btn-primary rounded-full mt-6">
              {gettext("Browse loans")} <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </section>
      </div>

      <%!-- Impact hero: total lent as the headline, repayment ring alongside. --%>
      <section
        :if={@summary.count > 0}
        class="relative overflow-hidden rounded-3xl bg-secondary text-secondary-content px-6 sm:px-10 py-10 sm:py-12"
      >
        <div
          class="pointer-events-none absolute -top-24 -right-20 size-80 rounded-full bg-primary/25 blur-3xl"
          aria-hidden="true"
        >
        </div>
        <div
          class="pointer-events-none absolute -bottom-32 left-1/4 size-96 rounded-full bg-accent/15 blur-3xl"
          aria-hidden="true"
        >
        </div>

        <div class="relative flex flex-col md:flex-row md:items-center gap-10 md:gap-14">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-3">
              <img
                :if={@current_user.avatar_url}
                src={@current_user.avatar_url}
                alt=""
                class="size-11 rounded-full object-cover ring-2 ring-secondary-content/25"
              />
              <div>
                <h1 class="font-display text-3xl sm:text-4xl font-semibold">
                  {gettext("My impact")}
                </h1>
                <p :if={@current_user.display_name} class="text-sm text-secondary-content/65 mt-0.5">
                  {gettext("Welcome back, %{name}", name: @current_user.display_name)}
                </p>
              </div>
            </div>

            <p class="font-display text-5xl sm:text-6xl font-semibold tracking-tight mt-8">
              {money(@summary.total_cents, "USD", @locale)}
            </p>
            <p class="text-sm uppercase tracking-wide text-secondary-content/60 mt-1">
              {gettext("Total lent")}
            </p>

            <div class="flex flex-wrap gap-x-10 gap-y-4 mt-8">
              <div>
                <div class="font-display text-3xl font-semibold">{num(@summary.count, @locale)}</div>
                <div class="text-sm text-secondary-content/70">{gettext("Loans supported")}</div>
              </div>
              <div>
                <div class="font-display text-3xl font-semibold">
                  {num(@summary.borrower_count, @locale)}
                </div>
                <div class="text-sm text-secondary-content/70">{gettext("Borrowers reached")}</div>
              </div>
              <div>
                <div class="font-display text-3xl font-semibold">
                  {num(length(@summary.countries), @locale)}
                </div>
                <div class="text-sm text-secondary-content/70">{gettext("Countries reached")}</div>
              </div>
            </div>
          </div>

          <div class="shrink-0 self-center text-center">
            <div class="relative inline-block">
              <svg
                viewBox="0 0 160 160"
                class="size-44 -rotate-90"
                role="img"
                aria-label={
                  gettext("%{percent}% of what you lent has been repaid to you", percent: @repaid_pct)
                }
              >
                <circle
                  cx="80"
                  cy="80"
                  r="70"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="12"
                  class="text-secondary-content/20"
                />
                <circle
                  :if={@repaid_pct > 0}
                  cx="80"
                  cy="80"
                  r="70"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="12"
                  stroke-linecap="round"
                  stroke-dasharray={ring_circumference()}
                  stroke-dashoffset={ring_offset(@repaid_pct)}
                  class="text-secondary-content"
                />
              </svg>
              <div class="absolute inset-0 grid place-items-center">
                <div>
                  <p class="font-display text-4xl font-semibold">{@repaid_pct}%</p>
                  <p class="text-[0.65rem] uppercase tracking-widest text-secondary-content/60 mt-0.5">
                    {gettext("Repaid to you")}
                  </p>
                </div>
              </div>
            </div>
            <p class="font-display text-xl font-semibold mt-2">
              {money(@summary.returned_cents, "USD", @locale)}
            </p>
          </div>
        </div>

        <p class="relative flex items-start gap-1.5 text-xs text-secondary-content/55 mt-8">
          <.icon name="hero-information-circle" class="size-4 shrink-0" />
          <span>
            {gettext(
              "Demo — repayments are simulated. Lending earns you no interest: the most that can come back is what you lent. In real lending, some of it would be lost to defaults."
            )}
          </span>
        </p>
      </section>

      <%!-- The page's one action: money that came back is ready to go out again. --%>
      <section
        :if={@summary.count > 0 and @summary.available_to_relend_cents > 0}
        class="rounded-2xl border border-primary/25 bg-primary/10 px-5 sm:px-6 py-4 flex flex-col sm:flex-row sm:items-center gap-4 mt-4"
      >
        <div class="grid size-11 shrink-0 place-items-center rounded-full bg-primary/15 text-primary">
          <.icon name="hero-arrow-path" class="size-5" />
        </div>
        <div class="flex-1">
          <p class="font-display text-lg sm:text-xl font-semibold text-secondary">
            {gettext("%{amount} ready to relend",
              amount: money(@summary.available_to_relend_cents, "USD", @locale)
            )}
          </p>
          <p class="text-sm text-base-content/70">
            {gettext("Repayments have come back to you — put them to work for another borrower.")}
          </p>
        </div>
        <.link navigate={~p"/loans"} class="btn btn-primary rounded-full">
          {gettext("Find a borrower")} <.icon name="hero-arrow-right" class="size-4" />
        </.link>
      </section>

      <%!-- Money coming back: cumulative scheduled vs received on active repayments. --%>
      <section :if={@summary.count > 0} class="card bg-base-100 border border-base-200 mt-4">
        <div class="card-body p-5 sm:p-6">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="font-display text-xl font-semibold text-secondary">
                {gettext("Money coming back")}
              </h2>
              <p class="text-xs text-base-content/50">
                {gettext(
                  "Cumulative repayments on loans currently repaying or behind schedule — estimates, not guarantees. The gap between the lines is repayment running behind schedule."
                )}
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <span
                :if={@flow.upcoming_30_cents > 0}
                class="badge border-0 bg-primary/10 text-primary gap-1"
              >
                <.icon name="hero-calendar-days" class="size-3.5" />
                {gettext("Next 30 days")}: <b>{money(@flow.upcoming_30_cents, "USD", @locale)}</b>
              </span>
              <button
                :if={@flow.overdue_cents > 0}
                class="badge border-0 bg-warning/20 text-warning-content/80 gap-1 hover:bg-warning/30"
                phx-click="facet"
                phx-value-dim="status"
                phx-value-key="delinquent"
                title={gettext("Show loans behind on payments")}
              >
                <.icon name="hero-exclamation-triangle" class="size-3.5" />
                {gettext("Behind schedule")}: <b>{money(@flow.overdue_cents, "USD", @locale)}</b>
              </button>
            </div>
          </div>

          <div :if={@chart} class="mt-2">
            <div class="flex items-center justify-end gap-4 text-xs text-base-content/60">
              <span class="inline-flex items-center gap-1.5">
                <svg width="22" height="6" aria-hidden="true">
                  <line
                    x1="0"
                    y1="3"
                    x2="22"
                    y2="3"
                    class="stroke-primary/50"
                    stroke-width="2"
                    stroke-dasharray="5 4"
                  />
                </svg>
                {gettext("Scheduled (estimate)")}
              </span>
              <span class="inline-flex items-center gap-1.5">
                <svg width="22" height="6" aria-hidden="true">
                  <line x1="0" y1="3" x2="22" y2="3" class="stroke-primary" stroke-width="2.5" />
                </svg>
                {gettext("Received so far")}
              </span>
            </div>

            <svg
              viewBox="0 0 720 240"
              class="w-full h-auto mt-1"
              role="img"
              aria-label={
                gettext("Cumulative repayment chart; the same numbers are in the table below.")
              }
            >
              <%!-- gridlines + y ticks --%>
              <g :for={t <- @chart.ticks}>
                <line
                  x1="46"
                  y1={t.y}
                  x2={720 - 12}
                  y2={t.y}
                  class="stroke-base-300"
                  stroke-width="1"
                />
                <text
                  x="40"
                  y={t.y + 3.5}
                  text-anchor="end"
                  font-size="10"
                  class="fill-base-content/50"
                >
                  {t.label}
                </text>
              </g>
              <line
                x1="46"
                y1={@chart.baseline}
                x2={720 - 12}
                y2={@chart.baseline}
                class="stroke-base-300"
                stroke-width="1"
              />
              <text
                :for={xl <- @chart.x_labels}
                x={xl.x}
                y={240 - 8}
                text-anchor="middle"
                font-size="10"
                class="fill-base-content/50"
              >
                {xl.label}
              </text>

              <%!-- today marker --%>
              <g :if={@chart.today_x}>
                <line
                  x1={@chart.today_x}
                  y1={14}
                  x2={@chart.today_x}
                  y2={@chart.baseline}
                  class="stroke-base-content/25"
                  stroke-width="1"
                />
                <text
                  x={@chart.today_x}
                  y={10}
                  text-anchor="middle"
                  font-size="9"
                  class="fill-base-content/45 uppercase tracking-wide"
                >
                  {gettext("Today")}
                </text>
              </g>

              <%!-- series --%>
              <polygon :if={@chart.recv_area} points={@chart.recv_area} class="fill-primary/10" />
              <polyline
                points={@chart.sched_path}
                fill="none"
                class="stroke-primary/50"
                stroke-width="2"
                stroke-dasharray="6 5"
                stroke-linejoin="round"
                stroke-linecap="round"
              />
              <polyline
                points={@chart.recv_path}
                fill="none"
                class="stroke-primary"
                stroke-width="2.5"
                stroke-linejoin="round"
                stroke-linecap="round"
              />
              <circle
                :if={@chart.recv_end}
                cx={@chart.recv_end.x}
                cy={@chart.recv_end.y_r}
                r="4.5"
                class="fill-primary stroke-base-100"
                stroke-width="2"
              />
              <text
                x={min(@chart.sched_end.x, 720 - 14)}
                y={max(@chart.sched_end.y_s - 8, 22)}
                text-anchor="end"
                font-size="11"
                font-weight="600"
                class="fill-base-content/70"
              >
                {@chart.end_label}
              </text>

              <%!-- hover layer: one column per month --%>
              <g :for={p <- @chart.points} class="group/pt" tabindex="0" style="outline: none">
                <rect
                  x={p.x - @chart.col_w / 2}
                  y="14"
                  width={@chart.col_w}
                  height={@chart.baseline - 14}
                  fill="transparent"
                />
                <g class="opacity-0 group-hover/pt:opacity-100 group-focus/pt:opacity-100 transition-opacity">
                  <line
                    x1={p.x}
                    y1="14"
                    x2={p.x}
                    y2={@chart.baseline}
                    class="stroke-base-content/30"
                    stroke-width="1"
                  />
                  <circle
                    cx={p.x}
                    cy={p.y_s}
                    r="4"
                    class="fill-primary/60 stroke-base-100"
                    stroke-width="2"
                  />
                  <circle
                    :if={p.show_recv}
                    cx={p.x}
                    cy={p.y_r}
                    r="4"
                    class="fill-primary stroke-base-100"
                    stroke-width="2"
                  />
                  <g transform={"translate(#{if p.flip, do: p.x - 172, else: p.x + 10}, 18)"}>
                    <rect
                      width="162"
                      height="52"
                      rx="8"
                      class="fill-base-100 stroke-base-300"
                      stroke-width="1"
                    />
                    <text x="10" y="16" font-size="10.5" font-weight="600" class="fill-base-content">
                      {p.label}
                    </text>
                    <text x="10" y="31" font-size="10" class="fill-base-content/60">
                      {gettext("Scheduled")}
                    </text>
                    <text x="152" y="31" font-size="10" text-anchor="end" class="fill-base-content">
                      {p.sched_str}
                    </text>
                    <text x="10" y="45" font-size="10" class="fill-base-content/60">
                      {gettext("Received")}
                    </text>
                    <text x="152" y="45" font-size="10" text-anchor="end" class="fill-base-content">
                      {if p.show_recv, do: p.recv_str, else: "—"}
                    </text>
                  </g>
                </g>
              </g>
            </svg>

            <details class="mt-1">
              <summary class="text-xs text-base-content/50 cursor-pointer hover:text-primary w-fit">
                {gettext("View as table")}
              </summary>
              <div class="overflow-x-auto mt-2">
                <table class="table table-xs table-zebra">
                  <thead>
                    <tr>
                      <th>{gettext("Month")}</th>
                      <th class="text-right">{gettext("Scheduled")}</th>
                      <th class="text-right">{gettext("Received")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={p <- @chart.points}>
                      <td>{p.label}</td>
                      <td class="text-right tabular-nums">{p.sched_str}</td>
                      <td class="text-right tabular-nums">
                        {if p.show_recv, do: p.recv_str, else: "—"}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </details>
          </div>

          <p :if={is_nil(@chart)} class="text-sm text-base-content/60 py-6 text-center">
            {if @filters == %{},
              do:
                gettext(
                  "No repayments are scheduled right now — money appears here once a loan you backed starts repaying."
                ),
              else: gettext("No scheduled repayments match your filters.")}
          </p>
        </div>
      </section>

      <%!-- Distribution facets: whole-portfolio counts, click to filter. --%>
      <div :if={@summary.count > 0} class="grid gap-4 lg:grid-cols-2 items-start mt-4">
        <section class="card bg-base-100 border border-base-200">
          <div class="card-body p-5 sm:p-6">
            <h2 class="font-display text-xl font-semibold text-secondary">
              {gettext("Sectors you support")}
            </h2>
            <p class="text-xs text-base-content/50">
              {gettext("Across your whole portfolio — click to filter")}
            </p>
            <div class="space-y-1 mt-2">
              <button
                :for={s <- @summary.sectors}
                class={[
                  "block w-full text-left rounded-lg px-2 py-1.5 transition hover:bg-base-200/60",
                  @filters[:sector_id] == s.id && "bg-primary/10 hover:bg-primary/15"
                ]}
                phx-click="facet"
                phx-value-dim="sector"
                phx-value-key={s.id}
                aria-pressed={to_string(@filters[:sector_id] == s.id)}
              >
                <div class="flex items-baseline justify-between gap-3">
                  <span class="text-sm font-medium truncate">{s.sector}</span>
                  <span class="text-sm tabular-nums text-base-content/55">
                    {num(s.count, @locale)}
                  </span>
                </div>
                <div class="h-2 rounded-full bg-primary/10 overflow-hidden mt-1">
                  <div
                    class="h-full rounded-full bg-primary"
                    style={"width: #{bar_width(s.count, @max_sector)}%"}
                  >
                  </div>
                </div>
              </button>
            </div>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-200">
          <div class="card-body p-5 sm:p-6">
            <h2 class="font-display text-xl font-semibold text-secondary">
              {gettext("Countries reached")}
            </h2>
            <p class="text-xs text-base-content/50">
              {gettext("Across your whole portfolio — click to filter")}
            </p>
            <div class="grid sm:grid-cols-2 gap-2 mt-3">
              <button
                :for={c <- @summary.country_counts}
                class={[
                  "flex items-center gap-2.5 rounded-xl px-3 py-2 text-left transition",
                  (@filters[:country] == c.code && "bg-primary/10 ring-1 ring-primary/40") ||
                    "bg-base-200/60 hover:bg-base-200"
                ]}
                phx-click="facet"
                phx-value-dim="country"
                phx-value-key={c.code}
                aria-pressed={to_string(@filters[:country] == c.code)}
              >
                <span class="text-xl leading-none">{country_flag(c.code)}</span>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium truncate">{country_name(c.code)}</p>
                  <p class="text-xs text-base-content/55">
                    {ngettext("%{count} loan", "%{count} loans", c.count,
                      count: num(c.count, @locale)
                    )}
                  </p>
                </div>
              </button>
            </div>
          </div>
        </section>
      </div>

      <%!-- Loans touched: slice & dice toolbar above grouped rollups or the flat list. --%>
      <section :if={@summary.count > 0} class="mt-8">
        <h2 class="font-display text-2xl font-semibold text-secondary">
          {gettext("Loans you've touched")}
        </h2>

        <div class="flex flex-wrap items-center gap-2 mt-4">
          <form phx-change="filter" class="contents">
            <select
              name="status"
              class="select select-sm rounded-full w-auto border-base-300"
              aria-label={gettext("Filter by status")}
            >
              <option value="">{gettext("All statuses")}</option>
              <option :for={s <- @facets.statuses} value={s.key} selected={@filters[:status] == s.key}>
                {loan_status_label(s.key)} · {num(s.count, @locale)}
              </option>
            </select>
            <select
              name="country"
              class="select select-sm rounded-full w-auto border-base-300"
              aria-label={gettext("Filter by country")}
            >
              <option value="">{gettext("All countries")}</option>
              <option
                :for={c <- @summary.country_counts}
                value={c.code}
                selected={@filters[:country] == c.code}
              >
                {country_flag(c.code)} {country_name(c.code)} · {num(c.count, @locale)}
              </option>
            </select>
            <select
              name="sector"
              class="select select-sm rounded-full w-auto border-base-300"
              aria-label={gettext("Filter by sector")}
            >
              <option value="">{gettext("All sectors")}</option>
              <option
                :for={s <- @summary.sectors}
                value={s.id}
                selected={@filters[:sector_id] == s.id}
              >
                {s.sector} · {num(s.count, @locale)}
              </option>
            </select>
            <select
              name="partner"
              class="select select-sm rounded-full w-auto border-base-300"
              aria-label={gettext("Filter by partner")}
            >
              <option value="">{gettext("All partners")}</option>
              <option
                :for={p <- @facets.partners}
                value={chip_key(p.key)}
                selected={@filters[:partner_id] == p.key}
              >
                {if p.key == :direct, do: trust_model_label("direct"), else: p.name} · {num(
                  p.count,
                  @locale
                )}
              </option>
            </select>
          </form>

          <div class="flex items-center gap-1.5 ms-auto">
            <span class="text-xs uppercase tracking-wide text-base-content/50">
              {gettext("Group by")}
            </span>
            <button
              :for={
                {val, lbl} <- [
                  {"", gettext("None")},
                  {"country", gettext("Country")},
                  {"status", gettext("Status")},
                  {"sector", gettext("Sector")},
                  {"partner", gettext("Partner")}
                ]
              }
              class={[
                "btn btn-xs rounded-full",
                ((@group_by || "") == val && "btn-secondary") || "btn-ghost border border-base-300"
              ]}
              phx-click="set_group"
              phx-value-group={val}
            >
              {lbl}
            </button>
          </div>
        </div>

        <div :if={@filters != %{}} class="flex flex-wrap items-center gap-2 mt-3">
          <button
            :for={{fkey, val} <- @filters}
            class="badge badge-lg gap-1.5 border-primary/30 bg-primary/10 text-secondary hover:bg-primary/20"
            phx-click="facet"
            phx-value-dim={chip_dim(fkey)}
            phx-value-key={chip_key(val)}
            title={gettext("Remove filter")}
          >
            {chip_label(fkey, val, @summary, @facets)} <.icon name="hero-x-mark" class="size-3" />
          </button>
          <button
            class="link text-sm text-base-content/60 hover:text-primary"
            phx-click="clear_filters"
          >
            {gettext("Clear all")}
          </button>
          <span :if={@totals} class="text-sm text-base-content/60 ms-auto">
            {ngettext("%{count} lending", "%{count} lendings", @totals.count,
              count: num(@totals.count, @locale)
            )} · {gettext("You lent")} <b>{money(@totals.total_cents, "USD", @locale)}</b>
            · {gettext("Repaid to you")} <b>{money(@totals.returned_cents, "USD", @locale)}</b>
          </span>
        </div>

        <div :if={@group_by} class="space-y-2 mt-4">
          <button
            :for={g <- @groups}
            class="group flex w-full items-center gap-4 rounded-2xl border border-base-200 bg-base-100 px-4 sm:px-5 py-3.5 text-left hover:border-primary/40 hover:shadow-lg transition"
            phx-click="drill"
            phx-value-dim={@group_by}
            phx-value-key={chip_key(g.key)}
            title={gettext("View these loans")}
          >
            <span :if={@group_by == "country"} class="text-2xl leading-none shrink-0">
              {country_flag(g.key)}
            </span>
            <div class="min-w-0 flex-1">
              <p :if={@group_by != "status"} class="font-semibold truncate">
                {group_title(@group_by, g)}
              </p>
              <span
                :if={@group_by == "status"}
                class={["badge badge-sm border-0 font-medium", loan_status_color(g.key)]}
              >
                {loan_status_label(g.key)}
              </span>
              <p class="text-xs text-base-content/55 mt-0.5">
                {ngettext("%{count} lending", "%{count} lendings", g.count,
                  count: num(g.count, @locale)
                )}
              </p>
            </div>
            <div class="text-right shrink-0">
              <p class="text-sm">
                {gettext("You lent")} <b>{money(g.lent_cents, "USD", @locale)}</b>
              </p>
              <p class="text-xs text-base-content/55">
                {gettext("Repaid to you")} <b>{money(g.returned_cents, "USD", @locale)}</b>
              </p>
            </div>
            <div class="hidden sm:block w-28 shrink-0">
              <div class="h-1.5 rounded-full bg-primary/10 overflow-hidden">
                <div
                  class="h-full rounded-full bg-primary"
                  style={"width: #{bar_width(g.returned_cents, g.lent_cents)}%"}
                >
                </div>
              </div>
            </div>
            <.icon
              name="hero-chevron-right"
              class="size-4 text-base-content/30 group-hover:text-primary shrink-0"
            />
          </button>
        </div>

        <div :if={is_nil(@group_by)} class="space-y-3 mt-4">
          <p :if={@loans == [] and @filters != %{}} class="text-center text-base-content/60 py-10">
            {gettext("No loans match your filters.")}
            <button class="link link-primary ml-1" phx-click="clear_filters">
              {gettext("Clear all")}
            </button>
          </p>
          <.link
            :for={item <- @loans}
            navigate={~p"/loans/#{item.slug}"}
            class="group flex items-stretch overflow-hidden rounded-2xl border border-base-200 bg-base-100 hover:border-primary/40 hover:shadow-lg transition"
          >
            <div class={["relative w-16 sm:w-24 shrink-0", card_pattern(item.country)]}>
              <div class="absolute inset-0 grid place-items-center text-2xl sm:text-3xl">
                {country_flag(item.country)}
              </div>
            </div>
            <div class="flex-1 min-w-0 px-4 sm:px-5 py-4">
              <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
                <h3 class="font-semibold leading-snug">{item.title}</h3>
                <span class={["badge badge-sm border-0 font-medium", loan_status_color(item.status)]}>
                  {loan_status_label(item.status)}
                </span>
              </div>
              <p class="text-xs text-base-content/60 mt-0.5">
                <span :if={item.borrower}>{item.borrower} · </span>{country_name(item.country)} · {item.sector}
              </p>
              <div class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1 mt-3 text-sm">
                <p>
                  {gettext("You lent")} <b>{money(item.amount_cents, "USD", @locale)}</b>
                  <span class="text-base-content/30 mx-1">·</span>
                  {gettext("Repaid to you")} <b>{money(item.returned_cents, "USD", @locale)}</b>
                </p>
                <span
                  :if={item.progress.total_count > 0}
                  class="text-xs tabular-nums text-base-content/55"
                >
                  {item.progress.paid_count}/{item.progress.total_count} {gettext("repayments")}
                </span>
              </div>
              <div
                :if={item.progress.total_count > 0}
                class="h-1.5 rounded-full bg-primary/10 overflow-hidden mt-2"
              >
                <div
                  class="h-full rounded-full bg-primary"
                  style={"width: #{bar_width(item.progress.paid_count, item.progress.total_count)}%"}
                >
                </div>
              </div>
            </div>
          </.link>
        </div>
      </section>

      <div
        :if={is_nil(@group_by) and (@cursor_stack != [] or @next_cursor)}
        class="flex justify-center items-center gap-3 mt-6"
      >
        <button
          class="btn btn-sm btn-outline rounded-full"
          phx-click="prev"
          disabled={@cursor_stack == []}
        >
          ‹ {gettext("Prev")}
        </button>
        <button
          class="btn btn-sm btn-outline rounded-full"
          phx-click="next"
          disabled={is_nil(@next_cursor)}
        >
          {gettext("Next")} ›
        </button>
      </div>
    </Layouts.app>
    """
  end
end
