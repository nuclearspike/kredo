defmodule KivaWeb.ChatLive do
  @moduledoc """
  The floating page-aware Kredo Assistant, as a **sticky** child LiveView, so a
  conversation survives navigation between pages.

  With no model connected it answers from a deterministic script and says how to
  connect one (`Kiva.AI.LLM.needs_setup?/0`), rather than degrading silently into
  a chatbot that cannot explain why it is dull.

  Rendered once in the root layout via `live_render(.., sticky: true)`, so it
  survives live navigation within a `live_session` — the conversation, messages,
  and open/closed state persist as the user moves around the app (SPA feel).
  Page-awareness is kept fresh by the `ChatNav` JS hook, which pushes the current
  path on every navigation.
  """
  use KivaWeb, :live_view

  alias Kiva.{AI, Commands}
  alias Kiva.AI.Assistant

  @impl true
  def mount(_params, session, socket) do
    user = with id when not is_nil(id) <- session["user_id"], do: Kiva.Accounts.get_user(id)
    locale = Kiva.Localization.normalize(session["locale"])
    Gettext.put_locale(KivaWeb.Gettext, locale)

    # Only open a conversation once the socket is connected, so the disconnected
    # static render doesn't create a stray conversation row on every page load.
    socket =
      if connected?(socket) do
        conv =
          AI.start_conversation(%{
            user_id: user && user.id,
            actor_role: role(user),
            locale: locale,
            page_context: %{"page" => "/"}
          })

        assign(socket, conversation_id: conv.id)
      else
        assign(socket, conversation_id: nil)
      end

    {:ok,
     assign(socket,
       current_user: user,
       locale: locale,
       page: "/",
       messages: [],
       open: false,
       needs_setup: Kiva.AI.LLM.needs_setup?()
     ), layout: false}
  end

  @impl true
  def handle_event("toggle", _, socket),
    do: {:noreply, assign(socket, open: !socket.assigns.open)}

  def handle_event("page_changed", %{"page" => page}, socket),
    do: {:noreply, assign(socket, page: page)}

  def handle_event("send", %{"message" => text}, socket) when is_binary(text) and text != "" do
    result = Assistant.respond(ctx(socket), text)

    messages =
      socket.assigns.messages ++
        [
          %{role: "user", text: text, action: nil},
          %{role: "assistant", text: result.reply, action: result[:action]}
        ]

    {:noreply, assign(socket, messages: messages)}
  end

  def handle_event("send", _, socket), do: {:noreply, socket}

  def handle_event("confirm_command", %{"preview-id" => pid}, socket) do
    preview = AI.get_action_preview!(String.to_integer(pid))
    params = preview.preview["params"] || %{}

    case Commands.execute(preview.command_key, socket.assigns.current_user, params) do
      {:ok, %{locale: code}} when preview.command_key == "set_locale" ->
        AI.mark_preview_executed(preview)
        {:noreply, redirect(socket, to: ~p"/locale/#{code}")}

      {:ok, _result} ->
        AI.mark_preview_executed(preview)
        {:noreply, append_assistant(socket, gettext("Done."))}

      {:error, reason} ->
        {:noreply,
         append_assistant(socket, "#{gettext("I couldn't complete that")}: #{inspect(reason)}")}
    end
  end

  defp append_assistant(socket, text),
    do:
      assign(socket,
        messages: socket.assigns.messages ++ [%{role: "assistant", text: text, action: nil}]
      )

  defp ctx(socket) do
    %{
      conversation_id: socket.assigns.conversation_id,
      actor: socket.assigns.current_user,
      role: role(socket.assigns.current_user),
      locale: socket.assigns.locale,
      page: socket.assigns.page || "/"
    }
  end

  defp role(nil), do: "public"
  defp role(%{role: r}), do: r

  @impl true
  def render(assigns) do
    ~H"""
    <div id="kiva-chat-root" phx-hook="ChatNav" class="fixed bottom-4 right-4 z-50">
      <div
        :if={@open}
        class="card bg-base-100 border border-base-300 shadow-[0_24px_70px_-10px_rgba(0,0,0,0.45)]! w-[calc(100vw-2rem)] sm:w-[32rem] max-w-[32rem] mb-2 absolute bottom-20 right-0"
      >
        <div class="card-body p-3 gap-2">
          <div class="flex items-center justify-between">
            <h3 class="font-semibold flex items-center gap-1">
              <.icon name="hero-sparkles" class="size-5 text-primary" /> {gettext("Kredo Assistant")}
            </h3>
            <button phx-click="toggle" class="btn btn-ghost btn-xs btn-circle">
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>

          <%!-- Say up front that no model is connected, so the limitation is
               discoverable without having to type a question first. --%>
          <div :if={@needs_setup} class="alert alert-info py-2 px-3 text-xs">
            <.icon name="hero-information-circle" class="size-4 shrink-0" />
            <span>
              {gettext(
                "Offline mode — scripted answers only. Ask me how to connect a model to switch on the full assistant."
              )}
            </span>
          </div>

          <div class="h-80 sm:h-96 overflow-y-auto space-y-2 text-sm pr-1">
            <p :if={@messages == []} class="text-base-content/50">
              {gettext("Ask me about loans, how lending works, or say “switch to Spanish”.")}
            </p>
            <div
              :for={m <- @messages}
              class={["chat", (m.role == "user" && "chat-end") || "chat-start"]}
              id={"chat-msg-#{m.role}-#{:erlang.phash2(m)}"}
            >
              <div class={[
                "chat-bubble whitespace-pre-line",
                m.role == "user" && "chat-bubble-primary"
              ]}>
                {m.text}
                <div :if={m[:action]} class="mt-2">
                  <button
                    phx-click="confirm_command"
                    phx-value-preview-id={m.action.preview_id}
                    class="btn btn-xs btn-primary"
                  >
                    <.icon name="hero-check" class="size-3" /> {m.action.label}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <form phx-submit="send" class="flex gap-1">
            <input
              id={"chat-input-#{length(@messages)}"}
              name="message"
              autocomplete="off"
              placeholder={gettext("Type a message")}
              class="input input-sm input-bordered flex-1"
            />
            <button class="btn btn-sm btn-primary">
              <.icon name="hero-paper-airplane" class="size-4" />
            </button>
          </form>
        </div>
      </div>

      <button
        phx-click="toggle"
        class="btn btn-primary btn-circle btn-lg size-16 shadow-[0_12px_32px_-6px_rgba(0,0,0,0.5)]!"
        title={gettext("Kredo Assistant")}
      >
        <.icon name="hero-chat-bubble-left-right" class="size-6" />
      </button>
    </div>
    """
  end
end
