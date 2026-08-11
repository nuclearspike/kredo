defmodule KivaWeb.LoanLive.Index do
  @moduledoc "Public localized loan browse with filters (localizedLoanSearch)."
  use KivaWeb, :live_view

  alias Kiva.{Commands, Lending, Pagination, Taxonomy}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Loans"),
       filters: %{status: "fundraising"},
       q: "",
       cursor: nil,
       cursor_stack: [],
       next_cursor: nil,
       selected: nil,
       drawer_open: false,
       drawer_amount: "2500"
     )
     |> assign_stats()
     |> assign_status_counts()
     |> assign_data()}
  end

  def handle_event("open_drawer", %{"slug" => slug}, socket) do
    case Lending.get_localized_loan(slug, socket.assigns.locale) do
      nil -> {:noreply, socket}
      profile -> {:noreply, assign(socket, selected: profile, drawer_open: true)}
    end
  end

  def handle_event("close_drawer", _, socket), do: {:noreply, assign(socket, drawer_open: false)}

  def handle_event("set_drawer_amount", %{"cents" => cents}, socket),
    do: {:noreply, assign(socket, drawer_amount: cents)}

  def handle_event("drawer_support", _, socket) do
    user = socket.assigns.current_user
    profile = socket.assigns.selected

    cond do
      is_nil(profile) ->
        {:noreply, socket}

      user && user.role == "lender" ->
        amount = socket.assigns.drawer_amount

        case Commands.execute("add_loan_to_basket", user, %{
               "loan_id" => profile.loan.id,
               "amount_cents" => amount
             }) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(drawer_open: false)
             |> put_flash(
               :info,
               gettext("Added %{amt} to your basket for %{name}.",
                 amt: money(String.to_integer(amount), "USD", socket.assigns.locale),
                 name: profile.borrower_name
               )
             )}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, inspect(reason))}
        end

      true ->
        {:noreply, push_navigate(socket, to: ~p"/login")}
    end
  end

  def handle_event("pick_sector", %{"id" => ""}, socket) do
    {:noreply,
     socket
     |> assign(filters: Map.delete(socket.assigns.filters, :sector_id))
     |> reset_page()
     |> assign_status_counts()
     |> assign_data()}
  end

  def handle_event("pick_sector", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(filters: Map.put(socket.assigns.filters, :sector_id, String.to_integer(id)))
     |> reset_page()
     |> assign_status_counts()
     |> assign_data()}
  end

  def handle_event("next", _, socket) do
    socket =
      assign(socket,
        cursor_stack: [socket.assigns.cursor | socket.assigns.cursor_stack],
        cursor: socket.assigns.next_cursor
      )

    {:noreply, assign_data(socket)}
  end

  def handle_event("prev", _, socket) do
    case socket.assigns.cursor_stack do
      [prev | rest] ->
        {:noreply, socket |> assign(cursor: prev, cursor_stack: rest) |> assign_data()}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_event("pick_status", %{"status" => s}, socket) do
    {:noreply,
     socket
     |> assign(filters: Map.put(socket.assigns.filters, :status, s))
     |> reset_page()
     |> assign_data()}
  end

  def handle_event("search", %{"q" => q}, socket) do
    filters =
      if q in [nil, ""],
        do: Map.delete(socket.assigns.filters, :q),
        else: Map.put(socket.assigns.filters, :q, q)

    {:noreply,
     socket
     |> assign(q: q, filters: filters)
     |> reset_page()
     |> assign_status_counts()
     |> assign_data()}
  end

  defp assign_stats(socket), do: assign(socket, stats: Lending.browse_stats(%{}))

  defp assign_status_counts(socket),
    do: assign(socket, status_counts: Lending.status_counts(socket.assigns.filters))

  defp reset_page(socket), do: assign(socket, cursor: nil, cursor_stack: [])

  defp assign_data(socket) do
    locale = socket.assigns.locale
    lim = Pagination.default_limit()
    f = socket.assigns.filters |> Map.put(:cursor, socket.assigns.cursor) |> Map.put(:limit, lim)
    rows = Lending.list_localized_loans(locale, f)

    {page, next} =
      if length(rows) > lim do
        page = Enum.take(rows, lim)
        last = List.last(page)
        {page, Pagination.encode({last.loan.inserted_at, last.loan.id})}
      else
        {rows, nil}
      end

    assign(socket, loans: page, next_cursor: next, sectors: Taxonomy.list_sectors(locale))
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="loans"
    >
      <section class="rounded-3xl bg-secondary text-secondary-content px-6 sm:px-10 py-10 sm:py-12">
        <h1 class="font-display text-4xl sm:text-5xl font-semibold leading-[1.1] max-w-2xl">
          {gettext("Lending that builds resilient communities.")}
        </h1>
        <p class="mt-4 text-lg text-secondary-content/80 max-w-xl">
          {gettext("Choose a borrower whose story moves you. Every loan is backed by trust.")}
        </p>
        <div class="flex flex-wrap gap-x-12 gap-y-4 mt-8">
          <div>
            <div class="font-display text-3xl font-semibold">
              {money(@stats.raised_cents, "USD", @locale)}
            </div>
            <div class="text-sm text-secondary-content/70">{gettext("Raised in the demo")}</div>
          </div>
          <div>
            <div class="font-display text-3xl font-semibold">{num(@stats.count, @locale)}</div>
            <div class="text-sm text-secondary-content/70">{gettext("Active loans")}</div>
          </div>
          <div>
            <div class="font-display text-3xl font-semibold">5</div>
            <div class="text-sm text-secondary-content/70">{gettext("Languages")}</div>
          </div>
        </div>
      </section>

      <div class="flex flex-wrap items-center gap-1.5 mt-6">
        <span class="text-xs uppercase tracking-wide text-base-content/50 mr-1 self-center">
          {gettext("Status")}
        </span>
        <button
          :for={
            {val, lbl} <- [
              {"fundraising", gettext("Fundraising")},
              {"repaying", gettext("Repaying")},
              {"completed", gettext("Completed")},
              {"delinquent", gettext("Delinquent")},
              {"defaulted", gettext("Defaulted")},
              {"all", gettext("All")}
            ]
          }
          class={[
            "btn btn-xs rounded-full",
            (@filters[:status] == val && "btn-secondary") || "btn-ghost border border-base-300"
          ]}
          phx-click="pick_status"
          phx-value-status={val}
        >
          {lbl}
          <span class="ml-1 font-normal opacity-60">{num(@status_counts[val] || 0, @locale)}</span>
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-2 mt-3">
        <button
          class={[
            "btn btn-sm rounded-full",
            (is_nil(@filters[:sector_id]) && "btn-primary") || "btn-outline border-base-300"
          ]}
          phx-click="pick_sector"
          phx-value-id=""
        >
          {gettext("All sectors")}
        </button>
        <button
          :for={s <- @sectors}
          class={[
            "btn btn-sm rounded-full",
            (@filters[:sector_id] == s.id && "btn-primary") || "btn-outline border-base-300"
          ]}
          phx-click="pick_sector"
          phx-value-id={s.id}
        >
          {s.name}
        </button>
        <%!-- phx-submit keeps Enter inside LiveView. Without it the browser
             submits the form natively, remounting the page and wiping both the
             box and the search the person just ran. --%>
        <form id="loan-search" phx-change="search" phx-submit="search" class="ml-auto">
          <input
            id="loan-search-q"
            name="q"
            value={@q}
            placeholder={gettext("Search")}
            phx-debounce="300"
            class="input input-bordered input-sm rounded-full w-40"
          />
        </form>
      </div>

      <div :if={@loans == []} class="text-center text-base-content/60 py-12">
        {gettext("No loans match your filters.")}
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-5">
        <.loan_card_wide
          :for={item <- @loans}
          item={item}
          locale={@locale}
          select_event="open_drawer"
        />
      </div>

      <.loan_drawer
        profile={@selected}
        open={@drawer_open}
        locale={@locale}
        can_lend={@current_user != nil and @current_user.role == "lender"}
        amount={@drawer_amount}
      />

      <div
        :if={@cursor_stack != [] or @next_cursor}
        class="flex justify-center items-center gap-3 mt-8"
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
