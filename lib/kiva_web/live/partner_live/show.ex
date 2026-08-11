defmodule KivaWeb.PartnerLive.Show do
  @moduledoc "Public localized partner profile + their loans."
  use KivaWeb, :live_view

  alias Kiva.{Partners, Lending}

  def handle_params(%{"slug" => slug}, _uri, socket) do
    case Partners.get_localized_partner(slug, socket.assigns.locale) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Partner not found."))
         |> push_navigate(to: ~p"/loans")}

      p ->
        loans =
          Lending.list_localized_loans(socket.assigns.locale)
          |> Enum.filter(&(&1.loan.partner_id == p.partner.id))

        {:noreply, assign(socket, partner: p, loans: loans, page_title: p.name)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="partner_profile"
    >
      <.link navigate={~p"/loans"} class="btn btn-ghost btn-sm gap-1">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("All loans")}
      </.link>

      <img
        :if={@partner.partner.image_url}
        src={@partner.partner.image_url}
        alt={@partner.name}
        class="w-full h-44 sm:h-56 object-cover rounded-2xl mt-3"
      />

      <div class="flex items-center gap-2 flex-wrap mt-3">
        <span class="badge badge-outline">{trust_model_label(@partner.partner.trust_model)}</span>
        <span class="badge badge-ghost">{country_name(@partner.partner.country_code)}</span>
        <span :if={@partner.fallback_used} class="badge badge-warning gap-1">
          <.icon name="hero-language" class="size-3" />{String.upcase(
            @partner.resolved_locale || "en"
          )}
        </span>
      </div>

      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary mt-2">
        {@partner.name}
      </h1>
      <p :if={@partner.summary} class="text-base-content/70">{@partner.summary}</p>
      <p :if={@partner.profile} class="mt-3 whitespace-pre-line">{@partner.profile}</p>

      <h2 class="text-xl font-semibold mt-6">{gettext("Loans from this partner")}</h2>
      <div :if={@loans == []} class="text-base-content/60 py-4">{gettext("No active loans.")}</div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-2">
        <.loan_card :for={item <- @loans} item={item} locale={@locale} />
      </div>
    </Layouts.app>
    """
  end
end
