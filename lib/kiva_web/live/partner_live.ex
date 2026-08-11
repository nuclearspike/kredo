defmodule KivaWeb.PartnerLive do
  @moduledoc """
  Partner chat-assisted loan application workspace. Pick/resume a borrower, reuse
  prior facts, fill the structured form, and submit for staff review. Every
  mutation goes through `Kiva.Commands` (the single mutation path).
  """
  use KivaWeb, :live_view

  alias Kiva.{Commands, LoanApplications, Taxonomy}
  alias Kiva.Localization.Resolver

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: gettext("Partner workspace"),
        partner_id: socket.assigns.current_user.managed_partner_id,
        mode: :list,
        draft: nil,
        src: nil,
        suggestions: %{},
        b_cursor: nil,
        b_stack: [],
        b_next: nil
      )
      |> load_lists()

    {:ok, socket}
  end

  defp load_lists(socket) do
    pid = socket.assigns.partner_id
    lim = Kiva.Pagination.default_limit()

    rows =
      (pid && LoanApplications.list_partner_borrowers(pid, socket.assigns[:b_cursor], lim)) || []

    bpage = Enum.take(rows, lim)

    bnext =
      if length(rows) > lim,
        do: Kiva.Pagination.encode({List.last(bpage).inserted_at, List.last(bpage).id}),
        else: nil

    assign(socket,
      borrowers: bpage,
      b_next: bnext,
      drafts: (pid && LoanApplications.list_partner_drafts(pid)) || [],
      overview: (pid && Kiva.Lending.partner_overview(pid)) || nil,
      sectors: Taxonomy.list_sectors(socket.assigns.locale),
      activities: Taxonomy.list_activities(socket.assigns.locale)
    )
  end

  def handle_event("b_next", _, socket) do
    {:noreply,
     socket
     |> assign(
       b_stack: [socket.assigns.b_cursor | socket.assigns.b_stack],
       b_cursor: socket.assigns.b_next
     )
     |> load_lists()}
  end

  def handle_event("b_prev", _, socket) do
    case socket.assigns.b_stack do
      [p | rest] -> {:noreply, socket |> assign(b_cursor: p, b_stack: rest) |> load_lists()}
      [] -> {:noreply, socket}
    end
  end

  def handle_event("new_loan", %{"borrower-id" => bid}, socket) do
    case Commands.execute("start_loan_application", socket.assigns.current_user, %{
           "borrower_id" => bid
         }) do
      {:ok, %{draft_id: id}} -> {:noreply, open_draft(socket, id)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("create_borrower", %{"borrower" => params}, socket) do
    case Commands.execute("create_borrower", socket.assigns.current_user, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Borrower added."))
         |> push_event("close-modal", %{id: "onboard_borrower_modal"})
         |> load_lists()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("edit_draft", %{"id" => id}, socket),
    do: {:noreply, open_draft(socket, String.to_integer(id))}

  def handle_event("back", _, socket),
    do: {:noreply, socket |> assign(mode: :list, draft: nil) |> load_lists()}

  def handle_event("save_draft", params, socket) do
    p = Map.put(params, "loan_draft_id", socket.assigns.draft.id)

    case Commands.execute("save_loan_draft", socket.assigns.current_user, p) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Draft saved."))
         |> open_draft(socket.assigns.draft.id)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("use_prior_terms", _, socket) do
    s = socket.assigns.suggestions

    Commands.execute("save_loan_draft", socket.assigns.current_user, %{
      "loan_draft_id" => socket.assigns.draft.id,
      "loan_amount_cents" => s[:prior_amount_cents],
      "term" => s[:prior_term_months]
    })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Applied prior terms."))
     |> open_draft(socket.assigns.draft.id)}
  end

  def handle_event("submit_review", _, socket) do
    case Commands.execute("submit_loan_for_review", socket.assigns.current_user, %{
           "loan_draft_id" => socket.assigns.draft.id
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Submitted for staff review. Translation jobs queued."))
         |> assign(mode: :list, draft: nil)
         |> load_lists()}

      {:error, {:ineligible, check, _}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Not ready to submit") <>
             ": #{check}. " <> gettext("Complete all required fields.")
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  defp open_draft(socket, id) do
    draft = LoanApplications.get_draft(id)
    src = draft && Enum.find(draft.translations, & &1.is_source)

    suggestions =
      (draft && draft.borrower && LoanApplications.reuse_suggestions(draft.borrower)) || %{}

    assign(socket, mode: :draft, draft: draft, src: src, suggestions: suggestions) |> load_lists()
  end

  defp borrower_name(b, locale) do
    case Resolver.resolve_public(b.translations, locale).row do
      nil -> b.public_id
      row -> row.display_name
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="partner"
    >
      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
        {gettext("Partner workspace")}
      </h1>

      <div :if={is_nil(@partner_id)} class="alert alert-warning mt-4">
        {gettext("Your account is not linked to a lending partner.")}
      </div>

      <%= if @partner_id do %>
        <div :if={@mode == :list}>
          <p class="text-base-content/70">
            {gettext("Start a new loan application for one of your borrowers, or onboard a new one.")}
          </p>

          <div :if={@overview} class="stats stats-vertical sm:stats-horizontal shadow mt-2">
            <div class="stat">
              <div class="stat-title">{gettext("Active loans")}</div>
              <div class="stat-value text-2xl">{@overview.count}</div>
            </div>
            <div class="stat">
              <div class="stat-title">{gettext("Raised for my borrowers")}</div>
              <div class="stat-value text-2xl">
                {money(@overview.total_funded_cents, "USD", @locale)}
              </div>
            </div>
            <div class="stat">
              <div class="stat-title">{gettext("Fundraising")}</div>
              <div class="stat-value text-2xl">{@overview.live_count}</div>
            </div>
            <div class="stat">
              <div class="stat-title">{gettext("Repayments due")}</div>
              <div class="stat-value text-2xl">{@overview.repayments_due_count}</div>
              <div :if={@overview.repayments_due_count > 0} class="stat-actions">
                <.link navigate={~p"/partner/repayments"} class="btn btn-xs btn-primary">
                  {gettext("Manage")}
                </.link>
              </div>
            </div>
          </div>

          <button class="btn btn-primary btn-sm mt-4" onclick="onboard_borrower_modal.showModal()">
            <.icon name="hero-plus" class="size-4" /> {gettext("Onboard a new borrower")}
          </button>

          <dialog id="onboard_borrower_modal" class="modal">
            <div class="modal-box">
              <h3 class="font-display text-xl font-semibold text-secondary">
                {gettext("Onboard a new borrower")}
              </h3>
              <form
                id="new-borrower-form"
                phx-submit="create_borrower"
                class="grid sm:grid-cols-2 gap-3 mt-4"
              >
                <input
                  name="borrower[name]"
                  placeholder={gettext("Borrower name")}
                  required
                  class="input input-bordered input-sm w-full sm:col-span-2"
                />
                <select name="borrower[country_code]" class="select select-bordered select-sm w-full">
                  <option value="GT">Guatemala</option>
                  <option value="KE">Kenya</option>
                  <option value="US">United States</option>
                </select>
                <select name="borrower[sector_id]" class="select select-bordered select-sm w-full">
                  <option value="">{gettext("Sector")}</option>
                  <option :for={s <- @sectors} value={s.id}>{s.name}</option>
                </select>
                <input
                  name="borrower[image_url]"
                  placeholder={gettext("Photo URL")}
                  class="input input-bordered input-sm w-full sm:col-span-2"
                />
                <input
                  name="borrower[public_bio]"
                  placeholder={gettext("Short bio")}
                  class="input input-bordered input-sm w-full sm:col-span-2"
                />
                <div class="modal-action sm:col-span-2">
                  <button type="button" class="btn btn-ghost" onclick="onboard_borrower_modal.close()">
                    {gettext("Cancel")}
                  </button>
                  <button class="btn btn-primary">{gettext("Add borrower")}</button>
                </div>
              </form>
            </div>
            <form method="dialog" class="modal-backdrop">
              <button>{gettext("close")}</button>
            </form>
          </dialog>

          <div class="grid sm:grid-cols-2 gap-3 mt-4">
            <div :for={b <- @borrowers} class="card bg-base-100 border border-base-200">
              <div class="card-body p-4 flex-row items-center justify-between">
                <div class="flex items-center gap-3">
                  <div :if={b.image_url} class="avatar">
                    <div class="w-9 rounded-full"><img src={b.image_url} alt="" /></div>
                  </div>
                  <div>
                    <p class="font-semibold">{borrower_name(b, @locale)}</p>
                    <p class="text-xs text-base-content/60">{Taxonomy.name(b.sector, @locale)}</p>
                  </div>
                </div>
                <button
                  class="btn btn-sm btn-primary"
                  phx-click="new_loan"
                  phx-value-borrower-id={b.id}
                >
                  <.icon name="hero-plus" class="size-4" /> {gettext("New loan")}
                </button>
              </div>
            </div>
          </div>

          <div :if={@b_stack != [] or @b_next} class="flex items-center gap-3 mt-4">
            <button
              class="btn btn-xs btn-outline rounded-full"
              phx-click="b_prev"
              disabled={@b_stack == []}
            >
              ‹ {gettext("Prev")}
            </button>
            <button
              class="btn btn-xs btn-outline rounded-full"
              phx-click="b_next"
              disabled={is_nil(@b_next)}
            >
              {gettext("Next")} ›
            </button>
          </div>

          <h2 :if={@drafts != []} class="text-xl font-semibold mt-8">
            {gettext("Drafts & submissions")}
          </h2>
          <ul class="mt-2 space-y-2">
            <li :for={d <- @drafts} class="border border-base-200 rounded p-2">
              <div class="flex items-center justify-between">
                <span>
                  #{d.id} ·
                  <span class={[
                    "badge badge-sm",
                    (d.status == "changes_requested" && "badge-warning") || "badge-ghost"
                  ]}>
                    {status_label(d.status)}
                  </span>
                </span>
                <button
                  :if={d.status in ["draft", "changes_requested"]}
                  class="btn btn-xs"
                  phx-click="edit_draft"
                  phx-value-id={d.id}
                >
                  {if(d.status == "changes_requested",
                    do: gettext("Address changes"),
                    else: gettext("Continue")
                  )}
                </button>
              </div>
              <p
                :if={d.status == "changes_requested" && d.changes_requested_reason}
                class="text-xs text-warning mt-1 flex items-center gap-1"
              >
                <.icon name="hero-exclamation-triangle" class="size-3" /> {d.changes_requested_reason}
              </p>
            </li>
          </ul>
        </div>

        <div :if={@mode == :draft && @draft} class="mt-2">
          <button class="btn btn-ghost btn-sm" phx-click="back">
            <.icon name="hero-arrow-left" class="size-4" /> {gettext("Back")}
          </button>

          <div :if={@suggestions[:prior_amount_cents]} class="alert alert-info mt-2 flex-wrap">
            <.icon name="hero-sparkles" class="size-5" />
            <span>
              {gettext("Reuse suggestion")}: {money(@suggestions[:prior_amount_cents], "USD", @locale)} / {@suggestions[
                :prior_term_months
              ]} {gettext("months")}
            </span>
            <button class="btn btn-xs" phx-click="use_prior_terms">
              {gettext("Use prior terms")}
            </button>
          </div>

          <form phx-submit="save_draft" class="grid sm:grid-cols-2 gap-3 mt-4">
            <label class="block">
              <span class="flex items-center gap-1.5 text-sm font-medium text-base-content/70 mb-1">
                {gettext("Amount")}
                <span class="badge badge-ghost badge-sm font-normal">{gettext("USD")}</span>
              </span>
              <input
                type="number"
                name="amount"
                step="25"
                min="25"
                class="input input-bordered input-sm w-full"
                value={@draft.loan_amount_cents > 0 && div(@draft.loan_amount_cents, 100)}
              />
            </label>
            <label class="block">
              <span class="flex items-center gap-1.5 text-sm font-medium text-base-content/70 mb-1">
                {gettext("Term")}
                <span class="badge badge-ghost badge-sm font-normal">{gettext("months")}</span>
              </span>
              <input
                type="number"
                name="term"
                class="input input-bordered input-sm w-full"
                value={@draft.repayment_term_months}
              />
            </label>
            <label class="block">
              <span class="block text-sm font-medium text-base-content/70 mb-1">
                {gettext("Sector")}
              </span>
              <select name="sector_id" class="select select-bordered select-sm w-full">
                <option value="">—</option>
                <option :for={s <- @sectors} value={s.id} selected={@draft.sector_id == s.id}>
                  {s.name}
                </option>
              </select>
            </label>
            <label class="block">
              <span class="block text-sm font-medium text-base-content/70 mb-1">
                {gettext("Source language")}
              </span>
              <select name="source_locale_code" class="select select-bordered select-sm w-full">
                <option
                  :for={code <- Kiva.Localization.supported_locales()}
                  value={code}
                  selected={@draft.source_locale_code == code}
                >
                  {locale_native_name(code)}
                </option>
              </select>
            </label>
            <label class="block sm:col-span-2">
              <span class="block text-sm font-medium text-base-content/70 mb-1">
                {gettext("Title")}
              </span>
              <input
                name="title"
                class="input input-bordered input-sm w-full"
                value={@src && @src.title}
              />
            </label>
            <label class="block sm:col-span-2">
              <span class="block text-sm font-medium text-base-content/70 mb-1">
                {gettext("Short description")}
              </span>
              <input
                name="short_description"
                class="input input-bordered input-sm w-full"
                value={@src && @src.short_description}
              />
            </label>
            <label class="block sm:col-span-2">
              <span class="block text-sm font-medium text-base-content/70 mb-1">
                {gettext("Borrower story")}
              </span>
              <textarea name="borrower_story" class="textarea textarea-bordered w-full" rows="3">{@src && @src.borrower_story}</textarea>
            </label>
            <label class="block sm:col-span-2">
              <span class="block text-sm font-medium text-base-content/70 mb-1">
                {gettext("How the loan will be used")}
              </span>
              <textarea name="loan_use" class="textarea textarea-bordered w-full" rows="2">{@src && @src.loan_use}</textarea>
            </label>
            <label class="block sm:col-span-2">
              <span class="block text-sm font-medium text-base-content/70 mb-1">
                {gettext("Public risk summary")}
              </span>
              <textarea name="risk_summary_public" class="textarea textarea-bordered w-full" rows="2">{@src && @src.risk_summary_public}</textarea>
            </label>
            <div class="sm:col-span-2 flex gap-2">
              <button class="btn btn-sm">{gettext("Save draft")}</button>
            </div>
          </form>

          <div class="divider">{gettext("Review & submit")}</div>
          <button class="btn btn-primary" phx-click="submit_review">
            <.icon name="hero-paper-airplane" class="size-4" /> {gettext("Submit for staff review")}
          </button>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
