defmodule KivaWeb.TeamLive.Index do
  @moduledoc "Lending teams hub: browse teams, a lender's portfolio, and create a team."
  use KivaWeb, :live_view

  alias Kiva.{Teams, Commands, Portfolio}

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: gettext("Lending teams")) |> load()}
  end

  defp load(socket) do
    user = socket.assigns.current_user

    assign(socket,
      teams: Teams.list_localized_teams(socket.assigns.locale),
      lender?: user && user.role == "lender",
      portfolio: (user && user.role == "lender" && Portfolio.portfolio_summary(user.id)) || nil
    )
  end

  def handle_event("create_team", %{"team" => params}, socket) do
    case Commands.execute("create_lending_team", socket.assigns.current_user, params) do
      {:ok, %{slug: slug}} -> {:noreply, push_navigate(socket, to: ~p"/teams/#{slug}")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="teams"
    >
      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
        {gettext("Lending teams")}
      </h1>

      <div :if={@portfolio} class="stats stats-vertical sm:stats-horizontal shadow mt-4">
        <div class="stat">
          <div class="stat-title">{gettext("Your lendings")}</div>
          <div class="stat-value text-2xl">{@portfolio.count}</div>
        </div>
        <div class="stat">
          <div class="stat-title">{gettext("Total lent")}</div>
          <div class="stat-value text-2xl">{money(@portfolio.total_cents, "USD", @locale)}</div>
        </div>
        <div class="stat">
          <div class="stat-title">{gettext("Repaid to you")}</div>
          <div class="stat-value text-2xl">{money(@portfolio.returned_cents, "USD", @locale)}</div>
        </div>
        <div class="stat">
          <div class="stat-title">{gettext("Available to relend")}</div>
          <div class="stat-value text-2xl text-success">
            {money(@portfolio.available_to_relend_cents, "USD", @locale)}
          </div>
          <.link
            :if={@portfolio.available_to_relend_cents > 0}
            navigate={~p"/loans"}
            class="link link-primary text-sm"
          >
            {gettext("Relend →")}
          </.link>
        </div>
      </div>

      <div :if={@lender?} class="mt-6">
        <button class="btn btn-primary" onclick="create_team_modal.showModal()">
          <.icon name="hero-plus" class="size-4" /> {gettext("Create a lending team")}
        </button>
      </div>

      <dialog :if={@lender?} id="create_team_modal" class="modal">
        <div class="modal-box">
          <h3 class="font-display text-xl font-semibold text-secondary">
            {gettext("Create a lending team")}
          </h3>
          <form phx-submit="create_team" class="grid sm:grid-cols-2 gap-3 mt-4">
            <input
              name="team[name]"
              placeholder={gettext("Team name")}
              required
              class="input input-bordered input-sm sm:col-span-2"
            />
            <select name="team[visibility]" class="select select-bordered select-sm">
              <option value="public">{gettext("Public")}</option>
              <option value="private">{gettext("Private")}</option>
              <option value="invite_only">{gettext("Invite only")}</option>
            </select>
            <select name="team[source_locale_code]" class="select select-bordered select-sm">
              <option
                :for={code <- Kiva.Localization.supported_locales()}
                value={code}
                selected={code == @locale}
              >
                {locale_native_name(code)}
              </option>
            </select>
            <input
              name="team[tagline]"
              placeholder={gettext("Tagline")}
              class="input input-bordered input-sm sm:col-span-2"
            />
            <textarea
              name="team[description]"
              placeholder={gettext("Description")}
              class="textarea textarea-bordered sm:col-span-2"
              rows="2"
            ></textarea>
            <div class="modal-action sm:col-span-2">
              <button type="button" class="btn btn-ghost" onclick="create_team_modal.close()">
                {gettext("Cancel")}
              </button>
              <button class="btn btn-primary">{gettext("Create team")}</button>
            </div>
          </form>
        </div>
        <form method="dialog" class="modal-backdrop">
          <button>{gettext("close")}</button>
        </form>
      </dialog>

      <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
        <.link
          :for={t <- @teams}
          navigate={~p"/teams/#{t.team.slug}"}
          class="card bg-base-100 border border-base-200 hover:border-primary/50 hover:shadow-lg transition overflow-hidden group"
        >
          <figure class="relative h-28 bg-gradient-to-br from-primary/20 to-accent/20 flex items-center justify-center overflow-hidden">
            <img
              :if={t.team.image_url}
              src={t.team.image_url}
              alt={t.name}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <span :if={!t.team.image_url} class="font-display text-4xl text-secondary/40">
              {String.first(t.name || "T")}
            </span>
            <span :if={t.fallback_used} class="absolute top-2 right-2 badge badge-warning badge-xs">
              {String.upcase(t.resolved_locale || "en")}
            </span>
          </figure>
          <div class="card-body p-4 gap-1">
            <h3 class="card-title text-base leading-snug">{t.name}</h3>
            <p class="text-sm text-base-content/70 line-clamp-2">{t.tagline}</p>
            <p class="text-xs text-base-content/50 flex items-center gap-1 mt-1">
              <.icon name="hero-users" class="size-3" /> {t.team.member_count} {gettext("members")} · {money(
                t.team.total_lent_cents,
                "USD",
                @locale
              )} {gettext("lent")}
            </p>
          </div>
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
