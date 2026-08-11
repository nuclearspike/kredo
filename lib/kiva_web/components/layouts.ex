defmodule KivaWeb.Layouts do
  @moduledoc """
  App layouts and shared chrome: the localized header (with globe language
  dropdown), footer, and the page-aware floating chat placeholder.
  """
  use KivaWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, default: nil
  attr :locale, :string, default: "en"
  attr :live_chat, :boolean, default: false, doc: "render the live chat (LiveView pages only)"
  attr :page, :string, default: nil, doc: "page label for chat context"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar sticky top-0 z-40 bg-base-100/85 backdrop-blur border-b border-base-300 px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href={~p"/"} class="flex items-center gap-2">
          <img src={~p"/images/logo.svg"} width="30" />
          <span class="font-display text-xl font-semibold text-secondary">
            Kre<span class="text-primary">do</span>
          </span>
        </a>
      </div>
      <div class="flex-none flex items-center gap-1">
        <.link navigate={~p"/loans"} class="btn btn-ghost btn-sm hidden sm:inline-flex">
          {gettext("Loans")}
        </.link>
        <.link navigate={~p"/teams"} class="btn btn-ghost btn-sm hidden sm:inline-flex">
          {gettext("Teams")}
        </.link>
        <.link
          :if={@current_user && @current_user.role == "lender"}
          navigate={~p"/portfolio"}
          class="btn btn-ghost btn-sm hidden sm:inline-flex"
        >
          {gettext("My impact")}
        </.link>
        <.link
          :if={@current_user && @current_user.role == "lender"}
          navigate={~p"/basket"}
          class="btn btn-ghost btn-sm"
        >
          <.icon name="hero-shopping-cart" class="size-4" />
        </.link>
        <.link
          :if={@current_user && @current_user.role in ["lender", "partner"]}
          navigate={~p"/notifications"}
          class="btn btn-ghost btn-sm relative"
        >
          <.icon name="hero-bell" class="size-4" />
          <span
            :if={Kiva.Notifications.unread_count(@current_user.id) > 0}
            class="badge badge-primary badge-xs absolute -top-1 -right-1"
          >
            {Kiva.Notifications.unread_count(@current_user.id)}
          </span>
        </.link>
        <.link navigate={~p"/faq"} class="btn btn-ghost btn-sm hidden sm:inline-flex">
          {gettext("Help & FAQ")}
        </.link>
        <.link
          :if={@current_user && @current_user.developer_enabled}
          navigate={~p"/developer"}
          class="btn btn-ghost btn-sm hidden sm:inline-flex"
        >
          {gettext("Developers")}
        </.link>

        <.language_dropdown locale={@locale} />

        <div :if={@current_user} class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1.5">
            <img
              :if={@current_user.avatar_url}
              src={@current_user.avatar_url}
              alt=""
              class="size-6 rounded-full object-cover"
            />
            <.icon :if={!@current_user.avatar_url} name="hero-user-circle" class="size-5" />
            <span class="hidden sm:inline">{@current_user.display_name || @current_user.email}</span>
          </div>
          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-box z-10 w-56 p-2 shadow border border-base-200"
          >
            <li class="menu-title">
              <span class="badge badge-primary badge-sm">{@current_user.role}</span>
            </li>
            <li><.link navigate={dashboard_path(@current_user)}>{gettext("My dashboard")}</.link></li>
            <li>
              <.link href={~p"/logout"} method="delete">{gettext("Sign out")}</.link>
            </li>
          </ul>
        </div>
        <.link :if={!@current_user} href={~p"/login"} class="btn btn-primary btn-sm">
          {gettext("Sign in")}
        </.link>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="bg-secondary text-secondary-content mt-16">
      <div class="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 py-10 grid gap-8 sm:grid-cols-3">
        <div>
          <div class="flex items-center gap-2">
            <img src={~p"/images/logo.svg"} width="26" class="brightness-0 invert" />
            <span class="font-display text-lg font-semibold">Kredo</span>
          </div>
          <p class="text-sm mt-3 text-secondary-content/75">
            {gettext(
              "A reimagined, multilingual, chat-first lending network. Loans that change lives — $25 at a time."
            )}
          </p>
        </div>
        <div>
          <p class="font-semibold text-sm">{gettext("Explore")}</p>
          <ul class="mt-3 space-y-1.5 text-sm text-secondary-content/80">
            <li>
              <.link navigate={~p"/loans"} class="hover:underline">{gettext("Browse loans")}</.link>
            </li>
            <li>
              <.link navigate={~p"/teams"} class="hover:underline">{gettext("Lending teams")}</.link>
            </li>
            <li>
              <.link navigate={~p"/faq"} class="hover:underline">{gettext("Help & FAQ")}</.link>
            </li>
            <li>
              <.link navigate={~p"/developers"} class="hover:underline">
                {gettext("Developers")}
              </.link>
            </li>
          </ul>
        </div>
        <div>
          <p class="font-semibold text-sm">{gettext("In every language")}</p>
          <p class="text-2xl mt-3">🇬🇧 🇩🇪 🇪🇸 🇫🇷 🇳🇱</p>
          <p class="text-xs mt-4 text-secondary-content/60">
            {gettext("Demo data only — no real money moves. Repayments are simulated.")}
          </p>
        </div>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  attr :locale, :string, required: true

  def language_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1" title={gettext("Language")}>
        <.icon name="hero-globe-alt" class="size-5" />
        <span class="hidden sm:inline">{locale_flag(@locale)} {String.upcase(@locale)}</span>
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box z-10 w-48 p-2 shadow border border-base-200"
      >
        <li :for={code <- supported_locales()}>
          <a href={~p"/locale/#{code}"} class={code == @locale && "active font-semibold"}>
            <span>{locale_flag(code)}</span> {locale_native_name(code)}
            <.icon :if={code == @locale} name="hero-check" class="size-4 ml-auto" />
          </a>
        </li>
      </ul>
    </div>
    """
  end

  attr :locale, :string, required: true
  attr :current_user, :map, default: nil

  @doc """
  Page-aware floating chat placeholder. Phase 3 replaces the static panel with a
  live Ask/Command chat; for now it is a no-JS expandable widget so every page
  visibly carries the assistant affordance.
  """
  def chat_widget(assigns) do
    ~H"""
    <details class="fixed bottom-4 right-4 z-50" id="kiva-chat-widget">
      <summary class="btn btn-primary btn-circle btn-lg shadow-lg list-none">
        <.icon name="hero-chat-bubble-left-right" class="size-6" />
      </summary>
      <div class="card bg-base-100 border border-base-200 shadow-xl w-80 absolute bottom-16 right-0">
        <div class="card-body p-4">
          <h3 class="font-semibold flex items-center gap-2">
            <.icon name="hero-sparkles" class="size-5 text-primary" /> {gettext("Kredo Assistant")}
          </h3>
          <p class="text-sm text-base-content/70">
            {gettext(
              "Page-aware help is coming online. Soon you can ask questions and take safe actions here — in your language."
            )}
          </p>
          <div class="text-xs text-base-content/50">
            {gettext("Language")}: {locale_native_name(@locale)}
          </div>
        </div>
      </div>
    </details>
    """
  end

  defp dashboard_path(%{role: "lender"}), do: ~p"/portfolio"
  defp dashboard_path(%{role: "borrower"}), do: ~p"/portal"
  defp dashboard_path(%{role: "partner"}), do: ~p"/partner"
  defp dashboard_path(%{role: role}) when role in ["staff", "admin"], do: ~p"/admin"
  defp dashboard_path(_), do: ~p"/loans"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
