defmodule KivaWeb.NotificationsLive do
  @moduledoc "Item 3 — the lender reveal feed (funded loans, repayments)."
  use KivaWeb, :live_view

  alias Kiva.Notifications

  def mount(_params, _session, socket) do
    uid = socket.assigns.current_user.id
    notes = Notifications.list_for_user(uid)
    # Viewing the feed marks everything read (clears the bell badge).
    Notifications.mark_all_read(uid)
    {:ok, assign(socket, page_title: gettext("Notifications"), notifications: notes)}
  end

  defp icon_for("loan_funded"), do: "hero-check-badge"
  defp icon_for("repayment"), do: "hero-banknotes"
  defp icon_for("borrower_update"), do: "hero-megaphone"
  defp icon_for("loan_outcome"), do: "hero-sparkles"
  defp icon_for("disbursal"), do: "hero-paper-airplane"
  defp icon_for("loan_approved"), do: "hero-check-badge"
  defp icon_for("changes_requested"), do: "hero-exclamation-triangle"
  defp icon_for(_), do: "hero-bell"

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="notifications"
    >
      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
        {gettext("Notifications")}
      </h1>

      <div :if={@notifications == []} class="text-base-content/50 py-8">
        {gettext("No notifications yet. Lend to a loan, then watch it fund and repay.")}
      </div>

      <ul class="space-y-2 mt-4">
        <li
          :for={n <- @notifications}
          class={[
            "card bg-base-100 border",
            (is_nil(n.read_at) && "border-primary") || "border-base-200"
          ]}
        >
          <div class="card-body p-3 flex-row items-start gap-3">
            <.icon name={icon_for(n.type)} class="size-6 text-primary shrink-0" />
            <div class="flex-1">
              <p class="font-semibold">{notif_title(n)}</p>
              <p class="text-sm text-base-content/70">{notif_body(n)}</p>
              <.link :if={n.link} navigate={n.link} class="link link-primary text-xs">
                {gettext("View")} →
              </.link>
            </div>
            <span class="text-xs text-base-content/40">
              {Calendar.strftime(n.inserted_at, "%b %d")}
            </span>
          </div>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
