defmodule KivaWeb.Developer.DashboardLive do
  @moduledoc "Developer dashboard: list and create applications (OAuth clients + API-key owners)."
  use KivaWeb, :live_view

  alias Kiva.Developers

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Developer dashboard"), revealed: nil)
     |> load_apps()}
  end

  defp load_apps(socket),
    do: assign(socket, apps: Developers.list_apps(socket.assigns.current_user))

  def handle_event("create_app", %{"app" => params}, socket) do
    case Developers.create_app(socket.assigns.current_user, params) do
      {:ok, {app, secret}} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Application created."))
         |> push_event("close-modal", %{id: "create_app_modal"})
         |> assign(revealed: %{kind: :secret, value: secret, app_id: app.app_id})
         |> load_apps()}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, KivaWeb.Developer.View.changeset_error(changeset))}
    end
  end

  def handle_event("dismiss_reveal", _params, socket),
    do: {:noreply, assign(socket, revealed: nil)}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} locale={@locale} page="developer">
      <div class="flex items-center justify-between gap-4">
        <div>
          <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
            {gettext("Developer dashboard")}
          </h1>
          <p class="text-xs text-base-content/50">
            {gettext("Your applications, OAuth client IDs, and API keys.")}
          </p>
        </div>
        <div class="flex items-center gap-2">
          <a
            href="/api/graphiql"
            target="_blank"
            rel="noopener"
            class="btn btn-outline btn-sm"
          >
            <.icon name="hero-code-bracket-square" class="size-4" /> {gettext("GraphQL explorer")}
          </a>
          <button class="btn btn-primary btn-sm" onclick="create_app_modal.showModal()">
            <.icon name="hero-plus" class="size-4" /> {gettext("Create application")}
          </button>
        </div>
      </div>

      <div :if={@apps == []} class="card bg-base-100 border border-base-200 mt-6">
        <div class="card-body items-center text-center">
          <.icon name="hero-cube" class="size-8 text-base-content/30" />
          <p class="text-sm text-base-content/60">
            {gettext("No applications yet. Create one to get an app ID and API keys.")}
          </p>
          <p class="text-xs">
            <.link navigate={~p"/developers"} class="link">{gettext("Read the API docs")}</.link>
          </p>
        </div>
      </div>

      <div class="grid sm:grid-cols-2 gap-4 mt-6">
        <div :for={app <- @apps} class="card bg-base-100 border border-base-200">
          <div class="card-body">
            <h2 class="card-title text-lg">{app.name}</h2>
            <p :if={app.description} class="text-xs text-base-content/60">{app.description}</p>
            <p class="font-mono text-xs mt-2 break-all">{app.app_id}</p>
            <p class="text-xs text-base-content/50">
              {ngettext("%{count} API key", "%{count} API keys", length(app.api_keys))}
            </p>
            <div class="card-actions justify-end">
              <.link navigate={~p"/developer/apps/#{app.app_id}"} class="btn btn-sm btn-outline">
                {gettext("Manage")}
              </.link>
            </div>
          </div>
        </div>
      </div>

      <dialog id="create_app_modal" class="modal">
        <div class="modal-box">
          <h3 class="font-display text-xl font-semibold text-secondary">
            {gettext("Create application")}
          </h3>
          <form phx-submit="create_app" class="grid gap-3 mt-4">
            <input
              name="app[name]"
              required
              placeholder={gettext("Application name")}
              class="input input-bordered input-sm w-full"
            />
            <textarea
              name="app[description]"
              placeholder={gettext("Description (optional)")}
              class="textarea textarea-bordered"
              rows="2"
            ></textarea>
            <input
              name="app[website]"
              placeholder={gettext("Website (optional)")}
              class="input input-bordered input-sm w-full"
            />
            <textarea
              name="app[redirect_uris]"
              placeholder={gettext("OAuth redirect URIs — one per line (optional)")}
              class="textarea textarea-bordered font-mono text-xs"
              rows="2"
            ></textarea>
            <div class="modal-action">
              <button type="button" class="btn btn-ghost" onclick="create_app_modal.close()">
                {gettext("Cancel")}
              </button>
              <button class="btn btn-primary">{gettext("Create")}</button>
            </div>
          </form>
        </div>
        <form method="dialog" class="modal-backdrop"><button>{gettext("close")}</button></form>
      </dialog>

      <KivaWeb.Developer.View.reveal_modal :if={@revealed} revealed={@revealed} />
    </Layouts.app>
    """
  end
end
