defmodule KivaWeb.AdminLive do
  @moduledoc """
  Staff/admin operations: loan review queue, translation review queue, permission
  outlier dashboard, and the audit timeline. Every action routes through
  `Kiva.Commands` (audited single mutation path).
  """
  use KivaWeb, :live_view

  alias Kiva.{Commands, Lending, Translation, Permissions, Audit, AI}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Admin"), event_filter: "", selected_conv: nil)
     |> load()}
  end

  defp load(socket) do
    assign(socket,
      analytics: Kiva.Analytics.overview(socket.assigns.locale),
      review_queue: Lending.review_queue(socket.assigns.locale),
      tx_queue: Translation.list_review_queue(),
      outliers: Permissions.list_outliers(),
      moderation_queue: Kiva.Messaging.list_moderation_queue(socket.assigns.locale),
      partners: Kiva.Partners.list_localized_partners(socket.assigns.locale),
      trustees: Kiva.Trust.list_trustees(socket.assigns.locale),
      ai_calls: AI.recent_tool_calls(25),
      events: Audit.list_events(limit: 25, event_type: socket.assigns.event_filter)
    )
  end

  def handle_event("approve_loan", %{"id" => id}, socket),
    do:
      run(
        socket,
        "approve_loan_listing",
        %{"loan_id" => id},
        gettext("Loan approved and published.")
      )

  def handle_event("request_changes", %{"loan_id" => id, "reason" => reason}, socket),
    do:
      run(
        socket,
        "request_loan_changes",
        %{"loan_id" => id, "reason" => reason},
        gettext("Changes requested — the partner was notified.")
      )

  def handle_event("approve_tx", %{"type" => type, "id" => id}, socket),
    do:
      run(
        socket,
        "approve_translation",
        %{"lc_entity_type" => type, "lc_id" => id},
        gettext("Translation approved.")
      )

  def handle_event("reject_tx", %{"type" => type, "id" => id}, socket),
    do:
      run(
        socket,
        "reject_translation",
        %{"lc_entity_type" => type, "lc_id" => id},
        gettext("Translation rejected.")
      )

  def handle_event("advance_time", _, socket) do
    case Commands.execute("advance_demo_time", socket.assigns.current_user, %{}) do
      {:ok, %{result: r}} ->
        msg =
          gettext("Advanced the demo") <>
            ": #{Map.get(r, :funded, 0)} funded, #{Map.get(r, :disbursed, 0)} disbursed, #{Map.get(r, :repaid, 0)} repaid."

        {:noreply, socket |> put_flash(:info, msg) |> load()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("revoke", %{"user_id" => uid, "permission_key" => key}, socket),
    do:
      run(
        socket,
        "revoke_permission",
        %{"user_id" => uid, "permission_key" => key},
        gettext("Permission revoked.")
      )

  def handle_event("set_partner_status", %{"id" => id, "status" => status}, socket),
    do:
      run(
        socket,
        "set_partner_status",
        %{"partner_id" => id, "status" => status},
        gettext("Partner status updated.")
      )

  def handle_event("set_trustee_status", %{"id" => id, "status" => status}, socket),
    do:
      run(
        socket,
        "set_trustee_status",
        %{"trustee_id" => id, "status" => status},
        gettext("Trustee status updated.")
      )

  def handle_event("approve_message", %{"id" => id}, socket),
    do:
      run(
        socket,
        "approve_message",
        %{"message_id" => id},
        gettext("Message approved and delivered to the borrower.")
      )

  def handle_event("reject_message", %{"id" => id}, socket),
    do: run(socket, "reject_message", %{"message_id" => id}, gettext("Message kept blocked."))

  def handle_event("filter_audit", %{"event_type" => t}, socket),
    do: {:noreply, socket |> assign(event_filter: t) |> load()}

  def handle_event("inspect_ai", %{"conversation_id" => cid}, socket) do
    conv = AI.get_conversation!(cid)

    {:noreply,
     assign(socket, selected_conv: %{conversation: conv, tool_calls: AI.list_tool_calls(conv.id)})}
  end

  def handle_event("close_ai", _, socket), do: {:noreply, assign(socket, selected_conv: nil)}

  defp run(socket, command, params, ok_msg) do
    case Commands.execute(command, socket.assigns.current_user, params) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, ok_msg) |> load()}
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
      page="admin"
    >
      <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary">
        {gettext("Staff & admin operations")}
      </h1>

      <div :if={@current_user.role == "admin"} class="card bg-base-200 mt-2">
        <div class="card-body p-3 flex-row items-center justify-between flex-wrap gap-2">
          <div>
            <p class="font-semibold">{gettext("Demo time machine")}</p>
            <p class="text-xs text-base-content/60">
              {gettext("Advance every active loan one step: fund → disburse → repay → complete.")}
            </p>
          </div>
          <button class="btn btn-sm btn-primary" phx-click="advance_time">
            <.icon name="hero-forward" class="size-4" /> {gettext("Advance a month")}
          </button>
        </div>
      </div>

      <section class="mt-6">
        <h2 class="text-xl font-semibold">{gettext("Distribution analytics")}</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 mt-2">
          <div class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <h3 class="font-semibold text-sm">{gettext("Loans by status")}</h3>
              <ul class="text-sm mt-1">
                <li :for={{label, n} <- @analytics.by_status} class="flex justify-between">
                  <span>{label}</span><span class="font-mono">{n}</span>
                </li>
              </ul>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <h3 class="font-semibold text-sm">{gettext("Loans by country")}</h3>
              <ul class="text-sm mt-1">
                <li :for={{label, n} <- @analytics.by_country} class="flex justify-between">
                  <span>{label}</span><span class="font-mono">{n}</span>
                </li>
              </ul>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <h3 class="font-semibold text-sm">{gettext("Funding raised by sector")}</h3>
              <ul class="text-sm mt-1">
                <li :for={{label, cents} <- @analytics.by_sector} class="flex justify-between gap-2">
                  <span class="truncate">{label}</span>
                  <span class="font-mono whitespace-nowrap">{money(cents, "USD", @locale)}</span>
                </li>
              </ul>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <h3 class="font-semibold text-sm">{gettext("Translation coverage by locale")}</h3>
              <ul class="text-sm mt-1">
                <li :for={{loc, n} <- @analytics.translation_coverage} class="flex justify-between">
                  <span>{loc}</span><span class="font-mono">{n}</span>
                </li>
              </ul>
            </div>
          </div>
          <div class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <h3 class="font-semibold text-sm">{gettext("AI tool calls")}</h3>
              <ul class="text-sm mt-1">
                <li :if={@analytics.ai_usage == []} class="text-base-content/50">
                  {gettext("none yet")}
                </li>
                <li :for={{label, n} <- @analytics.ai_usage} class="flex justify-between">
                  <span>{label}</span><span class="font-mono">{n}</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <section class="mt-6">
        <h2 class="text-xl font-semibold">
          {gettext("Loan review queue")} <span class="badge">{length(@review_queue)}</span>
        </h2>
        <p :if={@review_queue == []} class="text-base-content/50">
          {gettext("No loans awaiting review.")}
        </p>
        <div :for={item <- @review_queue} class="card bg-base-100 border border-base-200 mt-2">
          <div class="card-body p-3 flex-row items-center justify-between flex-wrap gap-2">
            <div>
              <p class="font-semibold">{item.title}</p>
              <p class="text-xs text-base-content/60">
                {item.borrower_name} · {item.sector_name} · {status_label(item.loan.status)}
              </p>
            </div>
            <div class="flex gap-2">
              <button
                class="btn btn-xs btn-primary"
                phx-click="approve_loan"
                phx-value-id={item.loan.id}
              >
                {gettext("Approve & publish")}
              </button>
              <button
                class="btn btn-xs btn-outline"
                onclick={"request_changes_modal_#{item.loan.id}.showModal()"}
              >
                {gettext("Request changes")}
              </button>
            </div>
          </div>
          <dialog id={"request_changes_modal_#{item.loan.id}"} class="modal">
            <div class="modal-box">
              <h3 class="font-display text-lg font-semibold text-secondary">
                {gettext("Request changes")}
              </h3>
              <p class="text-sm text-base-content/60 mt-1">{item.title}</p>
              <form phx-submit="request_changes" class="mt-3">
                <input type="hidden" name="loan_id" value={item.loan.id} />
                <textarea
                  name="reason"
                  placeholder={gettext("What needs to change before this can be published?")}
                  class="textarea textarea-bordered w-full"
                  rows="3"
                ></textarea>
                <div class="modal-action">
                  <button
                    type="button"
                    class="btn btn-ghost"
                    onclick={"request_changes_modal_#{item.loan.id}.close()"}
                  >
                    {gettext("Cancel")}
                  </button>
                  <button class="btn btn-primary">{gettext("Send back to partner")}</button>
                </div>
              </form>
            </div>
            <form method="dialog" class="modal-backdrop">
              <button>{gettext("close")}</button>
            </form>
          </dialog>

          <details :if={item.detail} class="px-3 pb-3 text-sm">
            <summary class="cursor-pointer text-primary">{gettext("Review details")}</summary>
            <div class="mt-2 space-y-2">
              <div :if={item.detail.missing != []} class="alert alert-warning p-2 text-xs">
                <.icon name="hero-exclamation-triangle" class="size-4" />
                {gettext("Missing")}: {Enum.join(item.detail.missing, ", ")}
              </div>
              <p :if={item.detail.story}>
                <span class="font-semibold">{gettext("Story")}:</span> {item.detail.story}
              </p>
              <p :if={item.detail.loan_use}>
                <span class="font-semibold">{gettext("Use")}:</span> {item.detail.loan_use}
              </p>
              <p :if={item.detail.risk_summary}>
                <span class="font-semibold">{gettext("Risk")}:</span> {item.detail.risk_summary}
              </p>
              <p :if={item.detail.repayment_summary}>
                <span class="font-semibold">{gettext("Repayment")}:</span> {item.detail.repayment_summary}
              </p>
              <div>
                <span class="font-semibold">{gettext("Translations")}:</span>
                <span :for={t <- item.detail.translations} class="badge badge-sm badge-ghost ml-1">
                  {t.locale}: {status_label(t.status)}{if t.is_source, do: " (src)"}
                </span>
              </div>
            </div>
          </details>
        </div>
      </section>

      <section class="mt-8">
        <h2 class="text-xl font-semibold">
          {gettext("Translation review queue")} <span class="badge">{length(@tx_queue)}</span>
        </h2>
        <p :if={@tx_queue == []} class="text-base-content/50">
          {gettext("Nothing awaiting translation review.")}
        </p>
        <table :if={@tx_queue != []} class="table table-sm mt-2">
          <thead>
            <tr>
              <th>{gettext("Type")}</th>
              <th>{gettext("Locale")}</th>
              <th>{gettext("Preview")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={t <- @tx_queue}>
              <td><span class="badge badge-sm badge-ghost">{t.entity_type}</span></td>
              <td>{String.upcase(t.locale)}</td>
              <td class="text-xs max-w-xs truncate">{t.snippet}</td>
              <td class="flex gap-1">
                <button
                  class="btn btn-xs btn-success"
                  phx-click="approve_tx"
                  phx-value-type={t.entity_type}
                  phx-value-id={t.lc_id}
                >
                  {gettext("Approve")}
                </button>
                <button
                  class="btn btn-xs btn-error btn-outline"
                  phx-click="reject_tx"
                  phx-value-type={t.entity_type}
                  phx-value-id={t.lc_id}
                >
                  {gettext("Reject")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section :if={@current_user.role == "admin"} class="mt-8">
        <h2 class="text-xl font-semibold">{gettext("Partners & trustees")}</h2>
        <table class="table table-sm mt-2">
          <thead>
            <tr>
              <th>{gettext("Partner")}</th>
              <th>{gettext("Country")}</th>
              <th>{gettext("Trust model")}</th>
              <th>{gettext("Status")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={pl <- @partners}>
              <td>{pl.name}</td>
              <td>{pl.partner.country_code}</td>
              <td class="text-xs">{pl.partner.trust_model}</td>
              <td>
                <span class={[
                  "badge badge-sm",
                  pl.partner.status == "suspended" && "badge-error",
                  pl.partner.status == "active" && "badge-success"
                ]}>
                  {status_label(pl.partner.status)}
                </span>
              </td>
              <td>
                <button
                  :if={pl.partner.status == "active"}
                  class="btn btn-xs btn-error btn-outline"
                  phx-click="set_partner_status"
                  phx-value-id={pl.partner.id}
                  phx-value-status="suspended"
                >
                  {gettext("Suspend")}
                </button>
                <button
                  :if={pl.partner.status != "active"}
                  class="btn btn-xs btn-success btn-outline"
                  phx-click="set_partner_status"
                  phx-value-id={pl.partner.id}
                  phx-value-status="active"
                >
                  {gettext("Reactivate")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <table :if={@trustees != []} class="table table-sm mt-4">
          <thead>
            <tr>
              <th>{gettext("Trustee")}</th>
              <th>{gettext("Country")}</th>
              <th>{gettext("Status")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={t <- @trustees}>
              <td>{t.name}</td>
              <td>{t.trustee.country_code}</td>
              <td>
                <span class={[
                  "badge badge-sm",
                  t.status == "suspended" && "badge-error",
                  t.status == "active" && "badge-success"
                ]}>
                  {status_label(t.status)}
                </span>
              </td>
              <td>
                <button
                  :if={t.status == "active"}
                  class="btn btn-xs btn-error btn-outline"
                  phx-click="set_trustee_status"
                  phx-value-id={t.trustee.id}
                  phx-value-status="suspended"
                >
                  {gettext("Suspend")}
                </button>
                <button
                  :if={t.status != "active"}
                  class="btn btn-xs btn-success btn-outline"
                  phx-click="set_trustee_status"
                  phx-value-id={t.trustee.id}
                  phx-value-status="active"
                >
                  {gettext("Reactivate")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <p class="text-xs text-base-content/40 mt-1">
          {gettext(
            "Suspension is a status flag in this demo — it does not cascade to hide existing loans."
          )}
        </p>
      </section>

      <section class="mt-8">
        <h2 class="text-xl font-semibold">
          {gettext("Encouragement moderation")} <span class="badge">{length(@moderation_queue)}</span>
        </h2>
        <p :if={@moderation_queue == []} class="text-base-content/50">
          {gettext("No held messages — the AI moderator approved everything.")}
        </p>
        <div :for={m <- @moderation_queue} class="card bg-base-100 border border-base-200 mt-2">
          <div class="card-body p-3">
            <div class="flex items-start justify-between gap-2 flex-wrap">
              <div>
                <span class={[
                  "badge badge-sm",
                  m.status == "blocked" && "badge-error",
                  m.status == "flagged" && "badge-warning"
                ]}>
                  {status_label(m.status)}
                </span>
                <p class="mt-1">“{m.body}”</p>
                <p class="text-xs text-base-content/60">{gettext("AI moderator")}: {m.reason}</p>
              </div>
              <div class="flex gap-2">
                <button
                  class="btn btn-xs btn-primary"
                  phx-click="approve_message"
                  phx-value-id={m.message.id}
                >
                  {gettext("Approve & deliver")}
                </button>
                <button
                  class="btn btn-xs btn-outline"
                  phx-click="reject_message"
                  phx-value-id={m.message.id}
                >
                  {gettext("Uphold block")}
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="mt-8">
        <h2 class="text-xl font-semibold">
          {gettext("Permission outliers")} <span class="badge">{length(@outliers)}</span>
        </h2>
        <p :if={@outliers == []} class="text-base-content/50">
          {gettext("No direct-grant outliers — everyone is within their role group.")}
        </p>
        <table :if={@outliers != []} class="table table-sm mt-2">
          <thead>
            <tr>
              <th>{gettext("User")}</th>
              <th>{gettext("Role")}</th>
              <th>{gettext("Direct permission")}</th>
              <th>{gettext("Risk")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={o <- @outliers}>
              <td>{o.email}</td>
              <td><span class="badge badge-sm">{o.role}</span></td>
              <td><code>{o.permission}</code></td>
              <td>
                <span class={["badge badge-sm", o.risk == "high" && "badge-error"]}>{o.risk}</span>
              </td>
              <td>
                <button
                  class="btn btn-xs btn-error btn-outline"
                  phx-click="revoke"
                  phx-value-user_id={o.user_id}
                  phx-value-permission_key={o.permission}
                >
                  {gettext("Revoke")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mt-8">
        <h2 class="text-xl font-semibold">
          {gettext("AI tool calls")} <span class="badge">{length(@ai_calls)}</span>
        </h2>
        <p :if={@ai_calls == []} class="text-base-content/50">
          {gettext("No AI tool calls recorded yet.")}
        </p>
        <table :if={@ai_calls != []} class="table table-sm mt-2">
          <thead>
            <tr>
              <th>{gettext("Tool")}</th>
              <th>{gettext("Surface / op")}</th>
              <th>{gettext("Allowed")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={c <- @ai_calls}>
              <td><span class="badge badge-sm badge-ghost">{c.tool_type}</span></td>
              <td class="text-xs">
                {c.schema_surface}{c.operation_name && " · #{c.operation_name}"}
              </td>
              <td>
                <span :if={c.allowed} class="badge badge-sm badge-success">{gettext("yes")}</span>
                <span :if={!c.allowed} class="badge badge-sm badge-error" title={c.denial_reason}>
                  {gettext("denied")}
                </span>
              </td>
              <td>
                <button
                  :if={c.ai_conversation_id}
                  class="btn btn-xs btn-ghost"
                  phx-click="inspect_ai"
                  phx-value-conversation_id={c.ai_conversation_id}
                >
                  {gettext("Inspect")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <div :if={@selected_conv} class="card bg-base-200 mt-3">
          <div class="card-body p-3">
            <div class="flex items-center justify-between">
              <p class="font-semibold">
                {gettext("Conversation")} {@selected_conv.conversation.id} · {@selected_conv.conversation.actor_role}
              </p>
              <button class="btn btn-xs btn-ghost" phx-click="close_ai">✕</button>
            </div>
            <div class="space-y-1 mt-2">
              <p :for={m <- @selected_conv.conversation.messages} class="text-sm">
                <span class="badge badge-xs">{m.role}</span> {m.content}
              </p>
            </div>
            <div :if={@selected_conv.tool_calls != []} class="mt-2">
              <p class="font-semibold text-sm">{gettext("Tool calls")}</p>
              <ul class="text-xs space-y-1">
                <li :for={c <- @selected_conv.tool_calls}>
                  <code>{c.tool_type}/{c.operation_name}</code>
                  — {if c.allowed,
                    do: gettext("allowed"),
                    else: gettext("DENIED: ") <> (c.denial_reason || "")}
                  <span :if={c.response_summary} class="text-base-content/60">
                    · {c.response_summary}
                  </span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <section class="mt-8">
        <h2 class="text-xl font-semibold">{gettext("Audit timeline")}</h2>
        <form phx-change="filter_audit" class="mt-2">
          <input
            name="event_type"
            value={@event_filter}
            placeholder={gettext("Filter by event type…")}
            class="input input-sm input-bordered w-full max-w-xs"
            phx-debounce="300"
          />
        </form>
        <ul class="timeline timeline-vertical mt-2">
          <li :for={e <- @events} class="text-sm">
            <div class="timeline-start text-xs text-base-content/50">{e.event_type}</div>
            <div class="timeline-middle"><.icon name="hero-check-circle" class="size-4" /></div>
            <div class="timeline-end timeline-box">
              {e.summary}
              <span :if={e.actor_role} class="text-xs text-base-content/50">· {e.actor_role}</span>
              <span :if={e.target_type} class="text-xs text-base-content/40">
                · {e.target_type}/{e.target_id}
              </span>
            </div>
            <hr />
          </li>
        </ul>
        <p :if={@events == []} class="text-base-content/50">{gettext("No matching events.")}</p>
      </section>
    </Layouts.app>
    """
  end
end
