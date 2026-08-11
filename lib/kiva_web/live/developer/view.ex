defmodule KivaWeb.Developer.View do
  @moduledoc "Shared view helpers + components for the developer portal LiveViews."
  use KivaWeb, :html

  @doc "Reveal-once dialog for a freshly created secret/API key (never re-renderable)."
  attr :revealed, :map, required: true

  def reveal_modal(assigns) do
    ~H"""
    <dialog class="modal modal-open">
      <div class="modal-box">
        <h3 class="font-display text-xl font-semibold text-secondary flex items-center gap-2">
          <.icon name="hero-key" class="size-5 text-warning" />
          {reveal_title(@revealed.kind)}
        </h3>
        <p class="text-sm text-warning mt-2">
          {gettext("Copy this now — for security, you won't be able to see it again.")}
        </p>
        <div class="mockup-code mt-3 text-xs">
          <pre><code>{@revealed.value}</code></pre>
        </div>
        <div class="modal-action">
          <button class="btn btn-primary" phx-click="dismiss_reveal">{gettext("Done")}</button>
        </div>
      </div>
    </dialog>
    """
  end

  defp reveal_title(:secret), do: gettext("Your client secret")
  defp reveal_title(:key), do: gettext("Your API key")
  defp reveal_title(_), do: gettext("Your credential")

  @doc "Format a datetime as a short date, or an em dash when nil."
  def fmt_date(nil), do: "—"
  def fmt_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")

  @doc "First validation error from a changeset, as a short string."
  def changeset_error(%Ecto.Changeset{} = cs) do
    cs
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end

  # --- documentation rendering --------------------------------------------

  @doc "A copyable code block (code is not localized)."
  attr :code, :string, required: true

  def code(assigns) do
    ~H"""
    <div class="relative group">
      <pre class="bg-neutral text-neutral-content rounded-lg p-3 text-xs overflow-x-auto"><code>{@code}</code></pre>
      <button
        type="button"
        class="btn btn-xs absolute top-2 right-2 opacity-70 hover:opacity-100"
        onclick="navigator.clipboard.writeText(this.parentElement.querySelector('code').innerText)"
      >
        {gettext("Copy")}
      </button>
    </div>
    """
  end

  @doc "Language tab bar driving the `set_language` event."
  attr :selected, :atom, required: true

  def language_tabs(assigns) do
    ~H"""
    <div role="tablist" class="tabs tabs-boxed bg-base-200 w-fit">
      <button
        :for={l <- KivaWeb.Developer.CodeGen.languages()}
        role="tab"
        class={["tab", l == @selected && "tab-active"]}
        phx-click="set_language"
        phx-value-lang={l}
      >
        {KivaWeb.Developer.CodeGen.language_label(l)}
      </button>
    </div>
    """
  end

  @doc "One endpoint: method/path/auth badge, description, params, and a code sample."
  attr :ep, :map, required: true
  attr :language, :atom, required: true

  def endpoint_card(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-200">
      <div class="card-body gap-2">
        <div class="flex items-center gap-2 flex-wrap">
          <span class={["badge badge-sm", method_class(@ep.method)]}>{@ep.method}</span>
          <code class="text-sm break-all">{@ep.path}</code>
          <span :if={@ep.auth != :none} class="badge badge-ghost badge-xs">
            {auth_label(@ep.auth)}
          </span>
        </div>
        <p class="font-medium">{@ep.title}</p>
        <p class="text-sm text-base-content/70">{@ep.description}</p>
        <.param_table :if={@ep.params != []} params={@ep.params} />
        <.code code={KivaWeb.Developer.CodeGen.render(@ep, @language)} />
      </div>
    </div>
    """
  end

  attr :params, :list, required: true

  def param_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-xs">
        <thead>
          <tr>
            <th>{gettext("Parameter")}</th>
            <th>{gettext("In")}</th>
            <th>{gettext("Description")}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={p <- @params}>
            <td class="font-mono">{p.name}{if p.required, do: "*", else: ""}</td>
            <td>{p.in}</td>
            <td>{p.desc}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc "Render a prose section's blocks (paragraphs, headings, lists, notes, code)."
  attr :blocks, :list, required: true

  def doc_blocks(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= for block <- @blocks do %>
        <%= case block do %>
          <% {:p, t} -> %>
            <p class="text-sm leading-relaxed">{t}</p>
          <% {:h, t} -> %>
            <h3 class="font-semibold text-secondary mt-4">{t}</h3>
          <% {:note, t} -> %>
            <div class="alert alert-info text-sm">{t}</div>
          <% {:ul, items} -> %>
            <ul class="list-disc ml-5 text-sm space-y-1">
              <li :for={i <- items}>{i}</li>
            </ul>
          <% {:code, _lang, c} -> %>
            <.code code={c} />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp method_class("GET"), do: "badge-info"
  defp method_class("POST"), do: "badge-success"
  defp method_class(_), do: "badge-neutral"

  defp auth_label(:api_key), do: gettext("API key")
  defp auth_label(:oauth), do: gettext("OAuth2")
  defp auth_label(:login), do: gettext("token")
  defp auth_label(_), do: ""
end
