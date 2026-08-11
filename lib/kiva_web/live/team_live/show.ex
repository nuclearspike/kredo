defmodule KivaWeb.TeamLive.Show do
  @moduledoc "Localized team profile + message board with on-demand post translation."
  use KivaWeb, :live_view

  alias Kiva.{Teams, Commands}

  def handle_params(%{"slug" => slug}, _uri, socket) do
    case Teams.get_localized_team(slug, socket.assigns.locale) do
      nil ->
        {:noreply,
         socket |> put_flash(:error, gettext("Team not found.")) |> push_navigate(to: ~p"/teams")}

      team ->
        {:noreply,
         assign(socket,
           team: team,
           slug: slug,
           page_title: team.name,
           lending: Teams.team_lending_summary(team.team.id, socket.assigns.locale)
         )}
    end
  end

  def handle_event("post", %{"body" => body}, socket) when body != "" do
    case Commands.execute("post_team_message", socket.assigns.current_user, %{
           "team_id" => socket.assigns.team.team.id,
           "body" => body,
           "source_locale_code" => socket.assigns.locale
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> push_event("reset-form", %{id: "team-post-form"})
         |> reload()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("You need to be signed in to post here."))}
    end
  end

  def handle_event("post", _, socket), do: {:noreply, socket}

  def handle_event("translate_post", %{"id" => id}, socket) do
    Teams.ensure_post_translation(String.to_integer(id), socket.assigns.locale)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Translation generated — machine, pending review."))
     |> reload()}
  end

  defp reload(socket) do
    team = Teams.get_localized_team(socket.assigns.slug, socket.assigns.locale)

    assign(socket,
      team: team,
      lending: Teams.team_lending_summary(team.team.id, socket.assigns.locale)
    )
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="team_profile"
    >
      <.link navigate={~p"/teams"} class="btn btn-ghost btn-sm gap-1">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("All teams")}
      </.link>

      <div class="flex items-start gap-4 mt-2">
        <div class="size-16 rounded-2xl bg-gradient-to-br from-primary/20 to-accent/20 flex items-center justify-center shrink-0 overflow-hidden">
          <img
            :if={@team.team.image_url}
            src={@team.team.image_url}
            alt=""
            class="w-full h-full object-cover"
          />
          <span :if={!@team.team.image_url} class="font-display text-2xl text-secondary/50">
            {String.first(@team.name || "T")}
          </span>
        </div>
        <div class="min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary leading-tight">
              {@team.name}
            </h1>
            <span :if={@team.fallback_used} class="badge badge-sm badge-warning">
              {String.upcase(@team.resolved_locale || "en")}
            </span>
          </div>
          <p :if={@team.tagline} class="text-base-content/70 mt-1">{@team.tagline}</p>
          <p class="text-sm text-base-content/50 mt-1">{@team.member_count} {gettext("members")}</p>
        </div>
      </div>
      <p :if={@team.description} class="mt-3 whitespace-pre-line text-base-content/80">
        {@team.description}
      </p>

      <div class="divider">{gettext("Lent through this team")}</div>
      <p class="text-sm">
        <span class="font-semibold">{money(@team.team.total_lent_cents, "USD", @locale)}</span>
        {gettext("lent across")} {@lending.count} {gettext("loans")}
      </p>
      <ul :if={@lending.recent != []} class="mt-2 space-y-1">
        <li
          :for={r <- @lending.recent}
          class="text-sm flex justify-between border-b border-base-200 pb-1"
        >
          <.link navigate={~p"/loans/#{r.slug}"} class="link">{r.title}</.link>
          <span>{money(r.amount_cents, "USD", @locale)}</span>
        </li>
      </ul>

      <div class="divider">{gettext("Message board")}</div>

      <form :if={@current_user} id="team-post-form" phx-submit="post" class="flex gap-2 mb-4">
        <input
          name="body"
          placeholder={gettext("Write an encouragement…")}
          class="input input-bordered input-sm flex-1"
        />
        <button class="btn btn-sm btn-primary">{gettext("Post")}</button>
      </form>

      <div :if={@team.posts == []} class="text-base-content/50">{gettext("No posts yet.")}</div>
      <div class="space-y-2">
        <div :for={p <- @team.posts} class="card bg-base-100 border border-base-200">
          <div class="card-body p-3 gap-2">
            <div class="flex items-center gap-2 flex-wrap">
              <img
                :if={p.author_avatar}
                src={p.author_avatar}
                alt=""
                class="size-7 rounded-full object-cover shrink-0"
              />
              <div
                :if={!p.author_avatar}
                class="size-7 rounded-full bg-base-200 flex items-center justify-center shrink-0"
              >
                <.icon name="hero-user" class="size-4 text-base-content/40" />
              </div>
              <span class="font-semibold text-sm">{p.author_name || gettext("A member")}</span>
              <span :if={p.author_role} class="badge badge-ghost badge-sm">
                {role_label(p.author_role)}
              </span>
              <span :if={p.captain?} class="badge badge-sm badge-primary gap-1">
                <.icon name="hero-star" class="size-3" /> {gettext("Captain")}
              </span>
              <span class="text-xs text-base-content/50 ml-auto">
                {fmt_datetime(p.posted_at, @locale)}
              </span>
            </div>

            <p class="whitespace-pre-line">{p.body}</p>

            <div class="flex items-center gap-2 text-xs text-base-content/50 flex-wrap">
              <span :if={p.joined_at} class="inline-flex items-center gap-1">
                <.icon name="hero-calendar-days" class="size-3" /> {gettext("Joined")} {fmt_month(
                  p.joined_at,
                  @locale
                )}
              </span>
              <span :if={p.status in ["machine", "needs_review"]} class="badge badge-info badge-xs">
                {gettext("machine · review pending")}
              </span>
              <button
                :if={p.fallback_used}
                phx-click="translate_post"
                phx-value-id={p.post.id}
                class="btn btn-xs btn-outline"
              >
                <.icon name="hero-language" class="size-3" /> {gettext("Translate to")} {locale_native_name(
                  @locale
                )}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
