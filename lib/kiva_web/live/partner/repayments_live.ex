defmodule KivaWeb.Partner.RepaymentsLive do
  @moduledoc """
  A partner's loans with a repayment still due — searchable and paged (moved off
  the dashboard, which previously loaded every loan the partner owns).
  """
  use KivaWeb, :live_view

  alias Kiva.{Commands, Lending}

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Repayments due"),
       partner_id: socket.assigns.current_user.managed_partner_id
     )}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, load(socket, params["q"] || "", parse_page(params["page"]))}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: ~p"/partner/repayments?#{%{q: q, page: 1}}")}
  end

  def handle_event("record_repayment", %{"id" => id}, socket) do
    Commands.execute("record_repayment", socket.assigns.current_user, %{"loan_id" => id})

    {:noreply,
     socket
     |> put_flash(:info, gettext("Repayment recorded — lenders were notified."))
     |> load(socket.assigns.q, socket.assigns.result.page)}
  end

  defp load(socket, q, page) do
    result =
      if socket.assigns.partner_id do
        Lending.partner_repayments_due(socket.assigns.partner_id, %{
          q: q,
          page: page,
          locale: socket.assigns.locale
        })
      else
        %{rows: [], page: 1, per_page: 25, total: 0, pages: 0, q: q}
      end

    assign(socket, result: result, q: q)
  end

  defp parse_page(nil), do: 1

  defp parse_page(s) do
    case Integer.parse(to_string(s)) do
      {n, _} when n >= 1 -> n
      _ -> 1
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} locale={@locale} page="partner">
      <.link navigate={~p"/partner"} class="text-sm link">‹ {gettext("Partner workspace")}</.link>
      <h1 class="font-display text-3xl font-semibold text-secondary mt-2">
        {gettext("Repayments due")}
      </h1>

      <div :if={is_nil(@partner_id)} class="alert alert-warning mt-4">
        {gettext("Your account is not linked to a lending partner.")}
      </div>

      <div :if={@partner_id}>
        <form id="repayments-search" phx-change="search" phx-submit="search" class="mt-4">
          <input
            id="repayments-search-q"
            type="text"
            name="q"
            value={@q}
            phx-debounce="300"
            placeholder={gettext("Search by borrower or loan…")}
            class="input input-bordered input-sm w-full sm:max-w-sm"
          />
        </form>

        <p class="text-xs text-base-content/50 mt-2">
          {ngettext("%{count} repayment due", "%{count} repayments due", @result.total)}
        </p>

        <div :if={@result.rows == []} class="alert mt-3">{gettext("No repayments due.")}</div>

        <ul :if={@result.rows != []} class="mt-3 space-y-2">
          <li
            :for={p <- @result.rows}
            class="flex items-center justify-between border border-base-200 rounded p-3"
          >
            <div>
              <.link navigate={~p"/loans/#{p.loan.slug}"} class="link font-medium">{p.title}</.link>
              <span class="text-xs text-base-content/60 block">
                {p.borrower_name} · {p.repayment.paid_count}/{p.repayment.total_count} {gettext(
                  "repaid"
                )}
              </span>
            </div>
            <button
              class="btn btn-xs btn-primary"
              phx-click="record_repayment"
              phx-value-id={p.loan.id}
            >
              {gettext("Record repayment")}
            </button>
          </li>
        </ul>

        <div :if={@result.pages > 1} class="flex items-center gap-3 mt-4">
          <.link
            :if={@result.page > 1}
            patch={~p"/partner/repayments?#{%{q: @q, page: @result.page - 1}}"}
            class="btn btn-xs btn-outline"
          >
            ‹ {gettext("Prev")}
          </.link>
          <span class="text-xs text-base-content/60">
            {gettext("Page")} {@result.page} / {@result.pages}
          </span>
          <.link
            :if={@result.page < @result.pages}
            patch={~p"/partner/repayments?#{%{q: @q, page: @result.page + 1}}"}
            class="btn btn-xs btn-outline"
          >
            {gettext("Next")} ›
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
