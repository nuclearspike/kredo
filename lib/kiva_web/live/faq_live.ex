defmodule KivaWeb.FaqLive do
  @moduledoc """
  Public Help/FAQ page — the worked demo of localized content with honest
  fallback state and on-demand machine translation.
  """
  use KivaWeb, :live_view

  alias Kiva.Content

  def mount(_params, _session, socket) do
    {:ok, assign_faqs(socket)}
  end

  def handle_event("translate", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user && socket.assigns.current_user.id
    Content.ensure_faq_translation(String.to_integer(id), socket.assigns.locale, user_id)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Translation generated — machine, pending review."))
     |> assign_faqs()}
  end

  defp assign_faqs(socket) do
    assign(socket,
      faqs: Content.list_localized_faqs(socket.assigns.locale),
      page_title: gettext("Help & FAQ")
    )
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="faq"
    >
      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
        {gettext("Help & FAQ")}
      </h1>
      <p class="text-base-content/70">
        {gettext(
          "Answers in your language. Where a translation is missing we show the original and offer an instant machine translation."
        )}
      </p>

      <div class="space-y-4 mt-6">
        <div :for={item <- @faqs} class="collapse collapse-arrow bg-base-100 border border-base-200">
          <input type="checkbox" checked={item.faq.position == 0} />
          <div class="collapse-title font-semibold flex items-center gap-2 flex-wrap">
            {(item.lc && item.lc.question) || item.faq.slug}
            <.lc_badge item={item} locale={@locale} />
          </div>
          <div class="collapse-content">
            <p class="whitespace-pre-line">{item.lc && item.lc.answer}</p>
            <div :if={item.fallback_used} class="mt-3">
              <button
                phx-click="translate"
                phx-value-id={item.faq.id}
                class="btn btn-xs btn-outline btn-primary"
              >
                <.icon name="hero-language" class="size-4" />
                {gettext("Translate to")} {locale_native_name(@locale)}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :item, :map, required: true
  attr :locale, :string, required: true

  defp lc_badge(assigns) do
    ~H"""
    <span :if={@item.fallback_used && !@item.missing} class="badge badge-warning badge-sm gap-1">
      <.icon name="hero-arrow-uturn-down" class="size-3" />
      {gettext("showing")} {String.upcase(@item.resolved_locale)}
    </span>
    <span :if={@item.status in ["machine", "needs_review"]} class="badge badge-info badge-sm">
      {gettext("machine · review pending")}
    </span>
    <span
      :if={@item.status in ["approved", "published", "source"]}
      class="badge badge-success badge-sm"
    >
      {gettext("human")}
    </span>
    """
  end
end
