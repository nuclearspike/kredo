defmodule KivaWeb.PortalLive do
  @moduledoc "Borrower native-language portal: loans, funding, repayment, encouragement."
  use KivaWeb, :live_view

  alias Kiva.{Borrowers, Lending, Messaging}

  def mount(_params, _session, socket) do
    borrower = Borrowers.get_by_user(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(page_title: gettext("My portal"), borrower: borrower)
      |> assign(
        loans:
          (borrower && Lending.list_loans_for_borrower(borrower.id, socket.assigns.locale)) || [],
        messages:
          (borrower && Messaging.list_for_borrower(borrower.id, socket.assigns.locale)) || []
      )

    {:ok, socket}
  end

  defp next_payment(%{schedule: %{items: items}}) when is_list(items) do
    Enum.find(items, &(&1.status == "scheduled")) || List.first(items)
  end

  defp next_payment(_), do: nil

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="portal"
    >
      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
        {gettext("My portal")}
      </h1>

      <div :if={is_nil(@borrower)} class="alert alert-info mt-4">
        {gettext("Your account is not linked to a borrower profile yet.")}
      </div>

      <p :if={@borrower} class="text-base-content/70">
        {gettext("Welcome")}, {Borrowers.display_name(@borrower, @locale)}. {gettext(
          "Here are your loans in your language."
        )}
      </p>

      <div :for={loan <- @loans} class="card bg-base-100 border border-base-200 mt-4">
        <div class="card-body">
          <div class="flex items-center gap-2 flex-wrap">
            <h2 class="card-title text-lg">{loan.title}</h2>
            <span class="badge badge-ghost">{status_label(loan.loan.status)}</span>
            <span :if={loan.fallback_used} class="badge badge-warning badge-sm">
              {String.upcase(loan.resolved_locale || "en")}
            </span>
          </div>
          <.funding_bar :if={Lending.Loan.fundraising?(loan.loan)} item={loan} locale={@locale} />
          <.repayment_progress
            :if={!Lending.Loan.fundraising?(loan.loan)}
            item={loan}
            locale={@locale}
          />
          <div :if={next_payment(loan)} class="text-sm mt-2">
            {gettext("Next repayment")}:
            <span class="font-semibold">{next_payment(loan).due_on}</span>
            — {money(next_payment(loan).amount_cents, loan.loan.currency_code, @locale)}
          </div>
        </div>
      </div>

      <div :if={@borrower} class="mt-8">
        <h2 class="text-xl font-semibold">{gettext("Messages of encouragement")}</h2>
        <p :if={@messages == []} class="text-base-content/50">{gettext("No messages yet.")}</p>
        <div class="space-y-2 mt-2">
          <div :for={m <- @messages} class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <p class="whitespace-pre-line">“{m.body}”</p>
              <span
                :if={m.status in ["machine", "needs_review"]}
                class="badge badge-info badge-xs w-fit"
              >
                {gettext("machine · review pending")}
              </span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
