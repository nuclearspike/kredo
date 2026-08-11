defmodule KivaWeb.DevelopersLive do
  @moduledoc """
  Public developer portal: landing + API documentation for all three surfaces
  (Platform REST/GraphQL + Kiva-compatible GraphQL/REST), a language tab bar that
  drives every code sample, an AI query builder, and the AI-agents Markdown view.
  """
  use KivaWeb, :live_view

  import KivaWeb.Developer.View,
    only: [endpoint_card: 1, language_tabs: 1, doc_blocks: 1, code: 1]

  alias KivaWeb.Developer.{Docs, CodeGen}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Developers"), nav: :overview, language: :curl)}
  end

  def handle_event("nav", %{"id" => id}, socket), do: {:noreply, assign(socket, nav: to_nav(id))}

  def handle_event("set_language", %{"lang" => lang}, socket),
    do: {:noreply, assign(socket, language: to_lang(lang))}

  defp nav_items do
    [
      {:overview, gettext("Overview")},
      {:auth, gettext("Authentication")},
      {:platform_rest, gettext("Platform REST")},
      {:platform_graphql, gettext("Platform GraphQL")},
      {:kiva_graphql, gettext("Kiva GraphQL")},
      {:kiva_rest, gettext("Kiva Legacy REST")},
      {:locales, gettext("Localization")},
      {:errors, gettext("Errors")},
      {:ai_builder, gettext("AI query builder")},
      {:ai_agents, gettext("AI agents (Markdown)")}
    ]
  end

  defp to_nav(id) do
    Enum.find(Enum.map(nav_items(), &elem(&1, 0)), :overview, &(to_string(&1) == id))
  end

  defp to_lang(l), do: Enum.find(CodeGen.languages(), :curl, &(to_string(&1) == l))

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} locale={@locale} page="developers">
      <div class="hero bg-base-200 rounded-box">
        <div class="hero-content text-center py-8">
          <div>
            <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
              {gettext("Kredo for developers")}
            </h1>
            <p class="text-sm text-base-content/60 mt-2 max-w-xl">
              {gettext(
                "Three public APIs — our modern Platform API plus a drop-in Kiva-compatible API. Create an app, get keys, and build."
              )}
            </p>
            <div class="mt-4 flex gap-2 justify-center flex-wrap">
              <.link
                :if={@current_user && @current_user.developer_enabled}
                navigate={~p"/developer"}
                class="btn btn-primary btn-sm"
              >
                {gettext("Go to dashboard")}
              </.link>
              <form
                :if={@current_user && !@current_user.developer_enabled}
                action={~p"/developers/enable"}
                method="post"
              >
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                <button class="btn btn-primary btn-sm">{gettext("Become a developer")}</button>
              </form>
              <.link :if={!@current_user} href={~p"/login"} class="btn btn-primary btn-sm">
                {gettext("Log in for API access")}
              </.link>
              <a href={~p"/developers/agents.md"} class="btn btn-ghost btn-sm">
                {gettext("agents.md")}
              </a>
            </div>
          </div>
        </div>
      </div>

      <div class="grid lg:grid-cols-4 gap-6 mt-6">
        <aside class="lg:col-span-1">
          <ul class="menu bg-base-100 rounded-box border border-base-200 w-full lg:sticky lg:top-20">
            <li :for={{id, label} <- nav_items()}>
              <button class={[id == @nav && "active"]} phx-click="nav" phx-value-id={id}>
                {label}
              </button>
            </li>
          </ul>
        </aside>

        <div class="lg:col-span-3 space-y-4">
          <div :if={@nav in [:overview, :auth, :locales, :errors]}>
            <h2 class="font-display text-2xl font-semibold text-secondary mb-3">
              {Docs.section(@nav).title}
            </h2>
            <.doc_blocks blocks={Docs.section(@nav).blocks} />
          </div>

          <div :if={@nav in [:platform_rest, :platform_graphql, :kiva_graphql, :kiva_rest]}>
            <h2 class="font-display text-2xl font-semibold text-secondary">
              {Docs.surface(@nav).name}
            </h2>
            <p class="text-sm text-base-content/60 mb-3">{Docs.surface(@nav).summary}</p>
            <.language_tabs selected={@language} />
            <div class="space-y-4 mt-3">
              <.endpoint_card :for={ep <- Docs.endpoints_for(@nav)} ep={ep} language={@language} />
            </div>
          </div>

          <div :if={@nav == :ai_builder}>
            <.live_component
              module={KivaWeb.Developer.QueryBuilderComponent}
              id="api-builder"
              locale={@locale}
            />
          </div>

          <div :if={@nav == :ai_agents}>
            <h2 class="font-display text-2xl font-semibold text-secondary">
              {gettext("AI agents (Markdown)")}
            </h2>
            <p class="text-sm text-base-content/70 mt-1">
              {gettext(
                "A complete, copy-pasteable Markdown reference for LLM agents and coding assistants. Append ?locale= to translate it."
              )}
            </p>
            <p class="mt-2">
              <a href={~p"/developers/agents.md"} class="link">{gettext("Open raw agents.md")}</a>
            </p>
            <div class="mt-3">
              <.code code={Docs.agents_markdown()} />
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
