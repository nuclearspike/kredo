defmodule KivaWeb.Developer.QueryBuilderComponent do
  @moduledoc """
  AI query builder: a developer describes what they want (in any language) and we
  return a ready-to-run example for a chosen surface + programming language.

  The LLM call runs via `start_async` so the LiveView never blocks on it (the
  request can take ~10s) — the form stays responsive and shows a loading state.
  Generation is display-only (never executed); it degrades to a deterministic
  docs example when the LLM is offline.
  """
  use KivaWeb, :live_component

  alias Kiva.AI.DocsAssistant
  alias KivaWeb.Developer.{Docs, CodeGen}

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:result, fn -> nil end)
     |> assign_new(:loading, fn -> false end)}
  end

  def handle_event("build", %{"intent" => intent} = params, socket) do
    req = %{
      intent: intent,
      language: params["language"] || "curl",
      surface: params["surface"] || "any",
      locale: socket.assigns[:locale] || "en"
    }

    {:noreply,
     socket
     |> assign(loading: true, result: nil)
     |> start_async(:build, fn -> DocsAssistant.generate(req) end)}
  end

  def handle_async(:build, {:ok, result}, socket) do
    {:noreply, assign(socket, loading: false, result: result)}
  end

  def handle_async(:build, {:exit, _reason}, socket) do
    {:noreply,
     assign(socket,
       loading: false,
       result: %{
         source: :error,
         summary: gettext("Something went wrong generating that request."),
         language: "",
         snippet: "",
         notes: gettext("Please try again.")
       }
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-200">
      <div class="card-body">
        <h2 class="card-title text-lg">
          <.icon name="hero-sparkles" class="size-5 text-primary" /> {gettext("AI query builder")}
        </h2>
        <p class="text-sm text-base-content/60">
          {gettext(
            "Describe what you want in any language and get a ready-to-run request. Examples are shown, never executed."
          )}
        </p>

        <form phx-submit="build" phx-target={@myself} class="grid gap-2 mt-2">
          <textarea
            name="intent"
            required
            rows="2"
            maxlength="500"
            class="textarea textarea-bordered"
            placeholder={gettext("e.g. list fundraising loans from Kenya, in Spanish")}
          ></textarea>
          <div class="flex gap-2 flex-wrap items-center">
            <select name="surface" class="select select-bordered select-sm">
              <option value="any">{gettext("Any surface")}</option>
              <option :for={s <- Docs.surfaces()} value={s.id}>{s.name}</option>
            </select>
            <select name="language" class="select select-bordered select-sm">
              <option :for={l <- CodeGen.languages()} value={l}>{CodeGen.language_label(l)}</option>
            </select>
            <button class="btn btn-primary btn-sm" disabled={@loading}>
              <span :if={@loading} class="loading loading-spinner loading-xs"></span>
              {if @loading, do: gettext("Building…"), else: gettext("Build it")}
            </button>
          </div>
        </form>

        <div :if={@loading} class="mt-3 flex items-center gap-2 text-sm text-base-content/60">
          <span class="loading loading-dots loading-sm"></span>
          {gettext("Composing your request…")}
        </div>

        <div :if={@result} class="mt-3 space-y-2">
          <p :if={@result.source in [:fallback, :error]} class="text-xs text-warning">
            {if @result.source == :error,
              do: @result.notes,
              else: gettext("AI is offline — here's a matching example from the docs.")}
          </p>
          <p :if={@result.summary != ""} class="text-sm font-medium">{@result.summary}</p>
          <pre
            :if={@result.snippet != ""}
            class="bg-neutral text-neutral-content rounded-lg p-3 text-xs overflow-x-auto"
          ><code>{@result.snippet}</code></pre>
          <p
            :if={@result.source != :error and @result.notes not in [nil, ""]}
            class="text-xs text-base-content/60"
          >
            {@result.notes}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
