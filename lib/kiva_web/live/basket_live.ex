defmodule KivaWeb.BasketLive do
  @moduledoc "Item 4 — the lending basket: review amounts, then check out (lends all)."
  use KivaWeb, :live_view

  alias Kiva.Basket

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: gettext("Basket")) |> load()}
  end

  defp load(socket) do
    uid = socket.assigns.current_user.id

    assign(socket,
      items: Basket.items(uid, socket.assigns.locale),
      total_cents: Basket.total_cents(uid)
    )
  end

  def handle_event("remove", %{"loan-id" => id}, socket) do
    Basket.remove(socket.assigns.current_user.id, String.to_integer(id))
    {:noreply, load(socket)}
  end

  def handle_event("checkout", _, socket) do
    %{lent: lent, skipped: skipped} = Basket.checkout(socket.assigns.current_user)

    cond do
      lent != [] and skipped == [] ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("You lent to %{count} loans! 🎉", count: length(lent)))
         |> push_navigate(to: ~p"/portfolio")}

      skipped != [] ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext(
             "Lent to %{lent} of %{total} — %{skipped} stayed in your basket because those loans are no longer fundraising.",
             lent: length(lent),
             total: length(lent) + length(skipped),
             skipped: length(skipped)
           )
         )
         |> load()}

      true ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="basket"
    >
      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
        {gettext("Your lending basket")}
      </h1>

      <div :if={@items == []} class="hero bg-base-200 rounded-box py-12 mt-4">
        <div class="hero-content text-center">
          <div>
            <p class="text-base-content/70">{gettext("Your basket is empty.")}</p>
            <.link navigate={~p"/loans"} class="btn btn-primary btn-sm mt-3">
              {gettext("Browse loans")}
            </.link>
          </div>
        </div>
      </div>

      <div :if={@items != []}>
        <ul class="space-y-2 mt-4">
          <li :for={item <- @items} class="card bg-base-100 border border-base-200">
            <div class="card-body p-3 flex-row items-center justify-between">
              <div>
                <.link navigate={~p"/loans/#{item.slug}"} class="font-semibold link">
                  {item.title}
                </.link>
                <p class="text-xs text-base-content/60">{item.borrower}</p>
              </div>
              <div class="flex items-center gap-3">
                <span class="font-semibold">{money(item.amount_cents, "USD", @locale)}</span>
                <button
                  phx-click="remove"
                  phx-value-loan-id={item.loan_id}
                  class="btn btn-ghost btn-xs btn-circle"
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </div>
            </div>
          </li>
        </ul>

        <div class="card bg-base-100 border border-base-200 mt-4">
          <div class="card-body p-4 flex-row items-center justify-between">
            <span class="text-lg">
              {gettext("Total")}: <b class="text-secondary">{money(@total_cents, "USD", @locale)}</b>
            </span>
            <button phx-click="checkout" class="btn btn-primary">
              <.icon name="hero-heart" class="size-4" /> {gettext("Lend all")}
            </button>
          </div>
        </div>
        <p class="text-xs text-base-content/50 mt-2">
          {gettext("Demo — no real money moves. Repayments are simulated.")}
        </p>
      </div>
    </Layouts.app>
    """
  end
end
