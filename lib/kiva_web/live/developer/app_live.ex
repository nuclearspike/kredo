defmodule KivaWeb.Developer.AppLive do
  @moduledoc "Single application: OAuth client credentials + API key management."
  use KivaWeb, :live_view

  alias Kiva.Developers

  def mount(_params, _session, socket), do: {:ok, assign(socket, revealed: nil)}

  def handle_params(%{"app_id" => app_id}, _uri, socket) do
    case Developers.get_app(socket.assigns.current_user, app_id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Application not found."))
         |> push_navigate(to: ~p"/developer")}

      app ->
        {:noreply, socket |> assign(page_title: app.name, app: app) |> load_keys()}
    end
  end

  defp load_keys(socket), do: assign(socket, keys: Developers.list_api_keys(socket.assigns.app))

  def handle_event("create_key", %{"key" => params}, socket) do
    {:ok, {_key, raw}} = Developers.create_api_key(socket.assigns.app, params)

    {:noreply,
     socket
     |> push_event("close-modal", %{id: "create_key_modal"})
     |> assign(revealed: %{kind: :key, value: raw})
     |> load_keys()}
  end

  def handle_event("revoke_key", %{"id" => id}, socket) do
    # Only keys belonging to this owner-scoped app are in `@keys`.
    case Enum.find(socket.assigns.keys, &(to_string(&1.id) == id)) do
      nil ->
        {:noreply, socket}

      key ->
        Developers.revoke_api_key(key)
        {:noreply, socket |> put_flash(:info, gettext("API key revoked.")) |> load_keys()}
    end
  end

  def handle_event("rotate_secret", _params, socket) do
    {:ok, {app, secret}} = Developers.rotate_secret(socket.assigns.app)

    {:noreply,
     socket
     |> assign(app: Developers.get_app(socket.assigns.current_user, app.app_id))
     |> assign(revealed: %{kind: :secret, value: secret, app_id: app.app_id})}
  end

  def handle_event("dismiss_reveal", _params, socket),
    do: {:noreply, assign(socket, revealed: nil)}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} locale={@locale} page="developer">
      <.link navigate={~p"/developer"} class="text-sm link">
        ‹ {gettext("All applications")}
      </.link>
      <h1 class="font-display text-3xl font-semibold text-secondary mt-2">{@app.name}</h1>
      <p :if={@app.description} class="text-sm text-base-content/60">{@app.description}</p>

      <div class="card bg-base-100 border border-base-200 mt-6">
        <div class="card-body">
          <h2 class="card-title text-lg">{gettext("OAuth client")}</h2>
          <div class="grid sm:grid-cols-2 gap-3 text-sm">
            <div>
              <p class="text-xs text-base-content/50">{gettext("Client ID (app ID)")}</p>
              <p class="font-mono break-all">{@app.app_id}</p>
            </div>
            <div>
              <p class="text-xs text-base-content/50">{gettext("Client secret")}</p>
              <p class="text-xs">{gettext("Shown once at creation.")}</p>
              <button class="btn btn-xs btn-outline mt-1" phx-click="rotate_secret">
                <.icon name="hero-arrow-path" class="size-3" /> {gettext("Rotate secret")}
              </button>
            </div>
          </div>
          <div class="mt-2">
            <p class="text-xs text-base-content/50">{gettext("Redirect URIs")}</p>
            <ul :if={@app.redirect_uris != []} class="font-mono text-xs list-disc ml-5">
              <li :for={uri <- @app.redirect_uris} class="break-all">{uri}</li>
            </ul>
            <p :if={@app.redirect_uris == []} class="text-xs text-base-content/40">
              {gettext("None registered.")}
            </p>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-200 mt-4">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title text-lg">{gettext("API keys")}</h2>
            <button class="btn btn-primary btn-sm" onclick="create_key_modal.showModal()">
              <.icon name="hero-plus" class="size-4" /> {gettext("Create key")}
            </button>
          </div>
          <p :if={@keys == []} class="text-sm text-base-content/50">
            {gettext("No API keys yet.")}
          </p>
          <div :if={@keys != []} class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>{gettext("Name")}</th>
                  <th>{gettext("Key")}</th>
                  <th>{gettext("Created")}</th>
                  <th>{gettext("Last used")}</th>
                  <th>{gettext("Status")}</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={key <- @keys}>
                  <td>{key.name || "—"}</td>
                  <td class="font-mono text-xs">{key.prefix}…{key.last4}</td>
                  <td class="text-xs">{KivaWeb.Developer.View.fmt_date(key.inserted_at)}</td>
                  <td class="text-xs">{KivaWeb.Developer.View.fmt_date(key.last_used_at)}</td>
                  <td>
                    <span :if={!key.revoked_at} class="badge badge-success badge-sm">
                      {gettext("active")}
                    </span>
                    <span :if={key.revoked_at} class="badge badge-ghost badge-sm">
                      {gettext("revoked")}
                    </span>
                  </td>
                  <td>
                    <button
                      :if={!key.revoked_at}
                      class="btn btn-xs btn-ghost text-error"
                      phx-click="revoke_key"
                      phx-value-id={key.id}
                      data-confirm={gettext("Revoke this key? Apps using it will stop working.")}
                    >
                      {gettext("Revoke")}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <dialog id="create_key_modal" class="modal">
        <div class="modal-box">
          <h3 class="font-display text-xl font-semibold text-secondary">
            {gettext("Create API key")}
          </h3>
          <form phx-submit="create_key" class="grid gap-3 mt-4">
            <input
              name="key[name]"
              placeholder={gettext("Label (optional), e.g. production")}
              class="input input-bordered input-sm w-full"
            />
            <div class="modal-action">
              <button type="button" class="btn btn-ghost" onclick="create_key_modal.close()">
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
