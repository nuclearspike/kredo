defmodule KivaWeb.LoanLive.Show do
  @moduledoc "Localized loan profile (localizedLoanProfile)."
  use KivaWeb, :live_view

  alias Kiva.{Lending, Commands, Teams}

  def handle_params(%{"slug" => slug}, _uri, socket) do
    case Lending.get_localized_loan(slug, socket.assigns.locale) do
      nil ->
        {:noreply,
         socket |> put_flash(:error, gettext("Loan not found.")) |> push_navigate(to: ~p"/loans")}

      profile ->
        user = socket.assigns.current_user

        lender? = user && user.role == "lender"
        my_teams = if lender?, do: Teams.list_user_teams(user.id, socket.assigns.locale), else: []
        basket_count = if lender?, do: Kiva.Basket.count(user.id), else: 0

        {:noreply,
         assign(socket,
           profile: profile,
           slug: slug,
           my_teams: my_teams,
           basket_count: basket_count,
           pending_lend: nil,
           last_lend: nil,
           messages: Kiva.Messaging.list_for_loan(profile.loan.id, socket.assigns.locale),
           trust: Kiva.Trust.get_trust_for_loan(profile.loan.id, socket.assigns.locale),
           updates: Kiva.Updates.list_for_loan(profile.loan.id, socket.assigns.locale),
           provenance: staff_provenance(user, profile.loan.id),
           page_title: profile.title
         )}
    end
  end

  def handle_event("encourage", %{"body" => body}, socket) do
    flash =
      case Commands.execute("submit_encouragement_message", socket.assigns.current_user, %{
             "loan_id" => socket.assigns.profile.loan.id,
             "body" => body,
             "source_locale_code" => socket.assigns.locale
           }) do
        {:ok, %{moderation: "approved"}} ->
          {:info, gettext("Your encouragement was sent and translated for the borrower.")}

        {:ok, %{moderation: "rejected", reason: r}} ->
          {:error, r}

        {:ok, %{moderation: "rewrite", suggestion: s}} ->
          {:info, s}

        {:error, reason} ->
          {:error, inspect(reason)}
      end

    {kind, text} = flash

    {:noreply,
     socket
     |> put_flash(kind, text)
     |> assign(
       messages:
         Kiva.Messaging.list_for_loan(socket.assigns.profile.loan.id, socket.assigns.locale)
     )}
  end

  def handle_event("record_disbursal", _, socket) do
    case Commands.execute("record_disbursal", socket.assigns.current_user, %{
           "loan_id" => socket.assigns.profile.loan.id
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Disbursal recorded — lenders were notified."))
         |> assign(
           profile: Lending.get_localized_loan(socket.assigns.slug, socket.assigns.locale)
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("record_repayment", _, socket) do
    case Commands.execute("record_repayment", socket.assigns.current_user, %{
           "loan_id" => socket.assigns.profile.loan.id
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Repayment recorded — lenders' balances updated."))
         |> assign(
           profile: Lending.get_localized_loan(socket.assigns.slug, socket.assigns.locale)
         )}

      {:error, :fully_repaid} ->
        {:noreply, put_flash(socket, :error, gettext("This loan is already fully repaid."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("lend_action", %{"action" => "basket"} = params, socket) do
    Commands.execute("add_loan_to_basket", socket.assigns.current_user, %{
      "loan_id" => socket.assigns.profile.loan.id,
      "amount_cents" => params["amount_cents"] || "2500"
    })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Added to your basket."))
     |> assign(basket_count: Kiva.Basket.count(socket.assigns.current_user.id))}
  end

  def handle_event("lend_action", params, socket) do
    team_id = if params["team_id"] in [nil, ""], do: nil, else: params["team_id"]

    {:noreply,
     assign(socket,
       pending_lend: %{amount_cents: params["amount_cents"] || "2500", team_id: team_id}
     )}
  end

  def handle_event("cancel_lend", _, socket), do: {:noreply, assign(socket, pending_lend: nil)}

  def handle_event("confirm_lend", _, socket) do
    p = socket.assigns.pending_lend
    before_pct = socket.assigns.profile.funded_percent

    case Commands.execute("complete_demo_lend", socket.assigns.current_user, %{
           "loan_id" => socket.assigns.profile.loan.id,
           "amount_cents" => p.amount_cents,
           "team_id" => p.team_id
         }) do
      {:ok, _} ->
        profile = Lending.get_localized_loan(socket.assigns.slug, socket.assigns.locale)

        {:noreply,
         assign(socket,
           profile: profile,
           pending_lend: nil,
           last_lend: %{
             amount: String.to_integer(p.amount_cents),
             before: before_pct,
             after: profile.funded_percent
           }
         )}

      {:error, reason} ->
        {:noreply, socket |> assign(pending_lend: nil) |> put_flash(:error, inspect(reason))}
    end
  end

  def handle_event("dismiss_celebration", _, socket),
    do: {:noreply, assign(socket, last_lend: nil)}

  def handle_event("post_update", %{"body" => body} = params, socket) when body != "" do
    Commands.execute("post_borrower_update", socket.assigns.current_user, %{
      "loan_id" => socket.assigns.profile.loan.id,
      "kind" => params["kind"] || "update",
      "body" => body,
      "source_locale_code" => socket.assigns.locale
    })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Update posted — lenders were notified."))
     |> assign(
       updates: Kiva.Updates.list_for_loan(socket.assigns.profile.loan.id, socket.assigns.locale)
     )}
  end

  def handle_event("post_update", _, socket), do: {:noreply, socket}

  def handle_event("translate_update", %{"id" => id}, socket) do
    Kiva.Updates.ensure_translation(String.to_integer(id), socket.assigns.locale)

    {:noreply,
     assign(socket,
       updates: Kiva.Updates.list_for_loan(socket.assigns.profile.loan.id, socket.assigns.locale)
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      live_chat={true}
      page="loan_profile"
    >
      <.link navigate={~p"/loans"} class="btn btn-ghost btn-sm gap-1">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("All loans")}
      </.link>

      <div :if={@last_lend} class="alert alert-success mt-2">
        <.icon name="hero-sparkles" class="size-6" />
        <div>
          <p class="font-bold">
            {gettext("Thank you for lending")} {money(@last_lend.amount, "USD", @locale)}! 🎉
          </p>
          <p class="text-sm">
            {gettext("You moved")} {@profile.borrower_name} {gettext("from")} {@last_lend.before}% → {@last_lend.after}% {gettext(
              "funded"
            )}.
          </p>
          <div class="flex gap-2 mt-1">
            <.link navigate={~p"/portfolio"} class="btn btn-xs">{gettext("View my impact")}</.link>
            <.link navigate={~p"/loans"} class="btn btn-xs btn-ghost">{gettext("Lend again")}</.link>
          </div>
        </div>
        <button phx-click="dismiss_celebration" class="btn btn-ghost btn-xs btn-circle">
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <div class="flex flex-col sm:flex-row items-start gap-6 mt-4">
        <div
          :if={@profile[:borrower_image]}
          class="relative w-full sm:flex-1 min-w-0 aspect-square rounded-3xl overflow-hidden"
        >
          <img
            src={@profile.borrower_image}
            alt={@profile.borrower_name}
            class="absolute inset-0 w-full h-full object-cover"
          />
          <span class="absolute bottom-3 left-3 inline-flex items-center gap-1 rounded-full bg-base-100/90 px-2.5 py-1 text-xs font-medium shadow-sm">
            {country_flag(@profile.loan.country_code)} {country_name(@profile.loan.country_code)}
          </span>
        </div>
        <div :if={!@profile[:borrower_image]} class="shrink-0">
          <div class="size-16 rounded-2xl bg-gradient-to-br from-primary/20 to-accent/20 flex items-center justify-center">
            <span class="font-display text-2xl text-secondary/50">
              {String.first(@profile.borrower_name || "K")}
            </span>
          </div>
        </div>
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-1.5 flex-wrap">
            <span class="badge badge-sm badge-ghost">
              {trust_model_label(@profile.loan.trust_model)}
            </span>
            <span :if={!@profile[:borrower_image]} class="badge badge-sm badge-ghost gap-1">
              <.icon name="hero-map-pin" class="size-3" />{country_name(@profile.loan.country_code)}
            </span>
            <span class="badge badge-sm badge-ghost">
              {disbursal_label(@profile.loan.disbursal_status)}
            </span>
            <span :if={@profile.fallback_used} class="badge badge-sm badge-warning gap-1">
              <.icon name="hero-language" class="size-3" /> {String.upcase(
                @profile.resolved_locale || "en"
              )}
            </span>
          </div>
          <h1 class="font-display text-3xl sm:text-4xl font-semibold text-secondary mt-1.5 leading-tight">
            {@profile.title}
          </h1>
          <p class="text-base-content/70 mt-1">
            {@profile.borrower_name} · {@profile.sector_name}<span :if={@profile.activity_name}> / {@profile.activity_name}</span>
            <span :if={@profile.partner_name}>
              ·
              <.link navigate={partner_path(@profile)} class="link link-primary">
                {@profile.partner_name}
              </.link>
            </span>
          </p>

          <div class="card bg-base-100 border border-base-200 mt-4">
            <div class="card-body">
              <.funding_bar
                :if={Lending.Loan.fundraising?(@profile.loan)}
                item={@profile}
                locale={@locale}
              />
              <div
                :if={@profile[:lenders_count] && @profile.lenders_count > 0}
                class="flex items-center gap-2 mt-2"
              >
                <div class="flex -space-x-2">
                  <img
                    :for={n <- ["l1", "l2", "l3", "l4"]}
                    src={"/images/lenders/#{n}.jpg"}
                    alt=""
                    class="size-7 rounded-full object-cover ring-2 ring-base-100"
                  />
                </div>
                <span class="text-sm text-base-content/60">
                  {@profile.lenders_count} {gettext("lenders")}
                </span>
              </div>
              <p
                :if={Lending.Loan.fundraising?(@profile.loan)}
                class="text-sm text-base-content/60 flex gap-3 mt-1"
              >
                <span :if={days_left(@profile.loan.fundraising_ends_at)} class="text-warning">
                  <.icon name="hero-clock" class="size-4" /> {days_left(
                    @profile.loan.fundraising_ends_at
                  )} {gettext("days left")}
                </span>
              </p>
              <div class="stats stats-vertical sm:stats-horizontal mt-2">
                <div class="stat">
                  <div class="stat-title">{gettext("Loan amount")}</div>
                  <div class="stat-value text-xl">
                    {money(@profile.loan.loan_amount_cents, @profile.loan.currency_code, @locale)}
                  </div>
                </div>
                <div class="stat">
                  <div class="stat-title">{gettext("Term")}</div>
                  <div class="stat-value text-xl">
                    {@profile.loan.repayment_term_months} {gettext("months")}
                  </div>
                </div>
              </div>
              <div :if={!Lending.Loan.lendable?(@profile.loan)} class="mt-3">
                <span class={["badge border-0 font-medium", loan_status_color(@profile.loan.status)]}>
                  {loan_status_label(@profile.loan.status)}
                </span>
                <p class="text-xs text-base-content/50 mt-1">
                  {gettext("Lending is closed for this loan.")}
                </p>
              </div>
              <form
                :if={
                  @current_user && @current_user.role == "lender" &&
                    Lending.Loan.lendable?(@profile.loan)
                }
                phx-submit="lend_action"
                class="mt-2 space-y-2"
              >
                <div class="flex items-end gap-2 flex-wrap">
                  <label class="block">
                    <span class="block text-xs font-medium text-base-content/70 mb-1">
                      {gettext("Amount")}
                    </span>
                    <select name="amount_cents" class="select select-bordered select-sm">
                      <option value="2500">$25</option>
                      <option value="5000">$50</option>
                      <option value="10000">$100</option>
                    </select>
                  </label>
                  <label :if={@my_teams != []} class="block">
                    <span class="block text-xs font-medium text-base-content/70 mb-1">
                      {gettext("Lend with a team")}
                    </span>
                    <select name="team_id" class="select select-bordered select-sm">
                      <option value="">{gettext("Just me")}</option>
                      <option :for={t <- @my_teams} value={t.id}>{t.name}</option>
                    </select>
                  </label>
                  <button name="action" value="basket" class="btn btn-outline btn-sm">
                    <.icon name="hero-shopping-cart" class="size-4" /> {gettext("Add to basket")}
                  </button>
                  <button name="action" value="lend" class="btn btn-primary btn-sm">
                    <.icon name="hero-heart" class="size-4" /> {gettext("Lend now")}
                  </button>
                </div>

                <div :if={@pending_lend} class="alert alert-info">
                  <div>
                    <p class="font-semibold">{gettext("Confirm your lending")}</p>
                    <p class="text-sm">
                      {gettext("You'll lend")} {money(
                        String.to_integer(@pending_lend.amount_cents),
                        "USD",
                        @locale
                      )} {gettext("to")} {@profile.borrower_name}.
                    </p>
                    <p class="text-xs opacity-70">
                      {gettext("Demo — no real money moves. Repayments are simulated.")}
                    </p>
                  </div>
                  <button type="button" phx-click="confirm_lend" class="btn btn-primary btn-sm">
                    {gettext("Confirm")}
                  </button>
                  <button type="button" phx-click="cancel_lend" class="btn btn-ghost btn-sm">
                    {gettext("Cancel")}
                  </button>
                </div>
              </form>

              <div
                :if={
                  !(@current_user && @current_user.role == "lender") &&
                    Lending.Loan.lendable?(@profile.loan)
                }
                class="mt-3"
              >
                <.link href={~p"/login"} class="btn btn-primary btn-sm">
                  <.icon name="hero-heart" class="size-4" /> {gettext("Lend to")} {@profile.borrower_name}
                </.link>
                <p class="text-xs text-base-content/50 mt-1 flex flex-wrap items-center gap-1.5">
                  {gettext("Sign in as a lender to lend.")}
                  <span class="badge badge-ghost badge-sm font-normal font-mono">
                    demo · lender@kredo.test / password
                  </span>
                </p>
              </div>

              <div
                :if={!Lending.Loan.fundraising?(@profile.loan) && @profile.repayment.total_count > 0}
                class="mt-3"
              >
                <.repayment_progress item={@profile} locale={@locale} />
                <button
                  :if={@current_user && @current_user.role in ["partner", "staff", "admin"]}
                  phx-click="record_repayment"
                  class="btn btn-xs btn-outline mt-1 w-fit"
                >
                  <.icon name="hero-banknotes" class="size-3" /> {gettext("Record next repayment")}
                </button>
              </div>

              <button
                :if={
                  @current_user && @current_user.role in ["partner", "staff", "admin"] &&
                    is_nil(@profile.loan.disbursed_at)
                }
                phx-click="record_disbursal"
                class="btn btn-xs btn-outline mt-2 w-fit"
              >
                <.icon name="hero-paper-airplane" class="size-3" /> {gettext("Record disbursal")}
              </button>
            </div>
          </div>
        </div>
      </div>

      <section :if={!Lending.Loan.fundraising?(@profile.loan)} class="mt-6">
        <h2 class="text-xl font-semibold">{gettext("Updates from the field")}</h2>
        <form
          :if={@current_user && @current_user.role in ["partner", "staff", "admin"]}
          phx-submit="post_update"
          class="flex gap-2 mt-2"
        >
          <select name="kind" class="select select-bordered select-sm">
            <option value="update">{gettext("Update")}</option>
            <option value="outcome">{gettext("Outcome")}</option>
          </select>
          <input
            name="body"
            placeholder={gettext("Share progress with lenders…")}
            class="input input-bordered input-sm flex-1"
          />
          <button class="btn btn-sm btn-primary">{gettext("Post")}</button>
        </form>
        <p :if={@updates == []} class="text-base-content/50 text-sm mt-2">
          {gettext("No updates yet.")}
        </p>
        <div class="space-y-2 mt-2">
          <div :for={u <- @updates} class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <span class={[
                "badge badge-sm w-fit",
                (u.kind == "outcome" && "badge-success") || "badge-info"
              ]}>
                {if(u.kind == "outcome", do: gettext("Outcome"), else: gettext("Update"))}
              </span>
              <p class="whitespace-pre-line">{u.body}</p>
              <button
                :if={u.fallback_used}
                phx-click="translate_update"
                phx-value-id={u.update.id}
                class="btn btn-xs btn-outline w-fit"
              >
                <.icon name="hero-language" class="size-3" /> {gettext("Translate to")} {locale_native_name(
                  @locale
                )}
              </button>
            </div>
          </div>
        </div>
      </section>

      <section :if={@profile.borrower_story} class="mt-6">
        <h2 class="text-xl font-semibold">{gettext("Borrower story")}</h2>
        <p class="whitespace-pre-line mt-1">{@profile.borrower_story}</p>
      </section>

      <section :if={@profile.loan_use} class="mt-4">
        <h2 class="text-xl font-semibold">{gettext("How the loan will be used")}</h2>
        <p class="mt-1">{@profile.loan_use}</p>
      </section>

      <section :if={@profile.risk_summary_public} class="mt-4">
        <h2 class="text-xl font-semibold">{gettext("Risk & trust")}</h2>
        <p class="mt-1">{@profile.risk_summary_public}</p>
      </section>

      <section class="mt-6">
        <h2 class="text-xl font-semibold">{gettext("Trust & verification")}</h2>
        <p class="text-sm text-base-content/70">
          <span class="badge badge-outline mr-1">{trust_model_label(@profile.loan.trust_model)}</span>
          {trust_model_explanation(@profile.loan.trust_model)}
        </p>

        <div :if={@trust.endorsements != []} class="mt-3">
          <h3 class="font-semibold">{gettext("Endorsements")}</h3>
          <div :for={e <- @trust.endorsements} class="card bg-base-100 border border-base-200 mt-1">
            <div class="card-body p-3">
              <p class="font-medium">{e.trustee_name}</p>
              <p class="text-sm italic">“{e.statement}”</p>
            </div>
          </div>
        </div>

        <div :if={@trust.checks != []} class="mt-3">
          <h3 class="font-semibold">{gettext("Verification checks")}</h3>
          <ul class="mt-1 space-y-1">
            <li :for={c <- @trust.checks} class="flex items-center gap-2 text-sm">
              <span class={[
                "badge badge-sm",
                (c.status == "passed" && "badge-success") || "badge-warning"
              ]}>
                {status_label(c.status)}
              </span>
              <span class="font-medium">{c.check_type}</span>
              <span class="text-base-content/60">{c.detail}</span>
            </li>
          </ul>
        </div>

        <div :if={@trust.attestation} class="alert mt-3 flex-wrap">
          <.icon name="hero-shield-check" class="size-5 text-success" />
          <div>
            <p class="font-semibold">
              {gettext("Blockchain attestation")} · {@trust.attestation.chain}
            </p>
            <p class="text-xs font-mono break-all">
              {String.slice(@trust.attestation.proof_hash, 0, 24)}…
            </p>
          </div>
          <span :if={@trust.attestation.verified} class="badge badge-success">
            {gettext("verified")}
          </span>
        </div>
      </section>

      <section class="mt-6">
        <h2 class="text-xl font-semibold">{gettext("Encouragement")}</h2>
        <form
          :if={@current_user && @current_user.role == "lender"}
          phx-submit="encourage"
          class="flex gap-2 mt-2"
        >
          <input
            name="body"
            placeholder={gettext("Write a kind message…")}
            class="input input-bordered input-sm flex-1"
          />
          <button class="btn btn-sm btn-primary">{gettext("Send")}</button>
        </form>
        <p :if={@messages == []} class="text-base-content/50 text-sm mt-2">
          {gettext("No messages yet.")}
        </p>
        <div class="space-y-2 mt-2">
          <div :for={m <- @messages} class="card bg-base-100 border border-base-200">
            <div class="card-body p-3">
              <p class="whitespace-pre-line text-sm">“{m.body}”</p>
            </div>
          </div>
        </div>
      </section>

      <section :if={@provenance} class="mt-6" id="provenance">
        <div class="flex flex-wrap items-center gap-2">
          <h2 class="text-xl font-semibold">{gettext("Authenticity & provenance")}</h2>
          <span class="badge badge-sm badge-ghost">{gettext("staff view")}</span>
        </div>
        <p class="text-xs text-base-content/50 mt-0.5">
          {gettext(
            "Append-only trail of how this listing was produced. Demo — the history shown here is fabricated for demonstration."
          )}
        </p>

        <p
          :if={@provenance.events == [] and not @provenance.fabrication_failed}
          class="text-sm text-base-content/60 mt-3"
        >
          {gettext("No provenance recorded for this listing.")}
        </p>
        <p
          :if={@provenance.fabrication_failed}
          class="text-sm text-warning-content/80 bg-warning/20 rounded-lg px-3 py-2 mt-3"
        >
          {gettext(
            "Provenance could not be loaded for this listing — the trail may be incomplete. Check the server logs."
          )}
        </p>

        <div :if={@provenance.events != []}>
          <div class="flex flex-wrap gap-2 mt-3">
            <span class="badge border-0 bg-base-200">
              {ngettext("%{count} event", "%{count} events", length(@provenance.events),
                count: length(@provenance.events)
              )}
            </span>
            <span
              :if={@provenance.broken == 0}
              class="badge border-0 bg-success/15 text-success gap-1"
            >
              <.icon name="hero-check-badge" class="size-3.5" /> {gettext("Hash chain verified")}
            </span>
            <span
              :if={@provenance.broken > 0}
              class="badge border-0 bg-warning/20 text-warning-content/80 gap-1"
            >
              <.icon name="hero-exclamation-triangle" class="size-3.5" />
              {ngettext("%{count} unlinked hash", "%{count} unlinked hashes", @provenance.broken,
                count: @provenance.broken
              )}
            </span>
            <span :if={@provenance.ai_reworded} class="badge border-0 bg-accent/15 text-accent gap-1">
              <.icon name="hero-cpu-chip" class="size-3.5" /> {gettext("Story AI-reworded")}
            </span>
            <span
              :if={@provenance.machine_translations > 0}
              class="badge border-0 bg-info/15 text-info"
            >
              {ngettext(
                "%{count} machine translation",
                "%{count} machine translations",
                @provenance.machine_translations,
                count: @provenance.machine_translations
              )}
            </span>
            <span :if={@provenance.photo_audience} class="badge border-0 bg-base-200">
              {gettext("Photo audience")}: {@provenance.photo_audience}
            </span>
          </div>

          <div class="grid gap-4 lg:grid-cols-2 mt-4 items-start">
            <div
              :for={{group, events} <- @provenance.groups}
              class="card bg-base-100 border border-base-200"
            >
              <div class="card-body p-4">
                <h3 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  {group_label(group)}
                </h3>
                <ol class="mt-2 space-y-3">
                  <li :for={e <- events} class="flex gap-3">
                    <div class="mt-0.5 shrink-0">
                      <.icon name={actor_icon(e.actor_kind)} class="size-4 text-base-content/50" />
                    </div>
                    <div class="min-w-0 flex-1 text-sm">
                      <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5">
                        <span class="font-medium">{event_label(e.event_type)}</span>
                        <span :if={e.target_locale} class="badge badge-xs badge-ghost uppercase">
                          {e.target_locale}
                        </span>
                        <span
                          :if={@provenance.chain[e.id] == :linked}
                          class="badge badge-xs border-0 bg-success/15 text-success"
                          title={gettext("Derived from a verified earlier artifact")}
                        >
                          {gettext("chain")} ✓
                        </span>
                        <span
                          :if={@provenance.chain[e.id] == :broken}
                          class="badge badge-xs border-0 bg-warning/20 text-warning-content/80"
                          title={gettext("Source hash does not match any earlier artifact")}
                        >
                          {gettext("unlinked")}
                        </span>
                        <span :if={e.visibility != "admin"} class="badge badge-xs badge-ghost">
                          {e.visibility}
                        </span>
                      </div>
                      <p class="text-xs text-base-content/60">
                        {e.actor_name}<span :if={e.actor_role}> · {e.actor_role}</span> · {fmt_datetime(
                          e.occurred_at,
                          @locale
                        )}
                      </p>
                      <p :if={tool_line(e.tool)} class="text-xs text-base-content/50">
                        {tool_line(e.tool)}
                      </p>
                      <p :if={location_line(e.location)} class="text-xs text-base-content/50">
                        <.icon name="hero-map-pin" class="size-3 inline" /> {location_line(e.location)}
                      </p>
                      <p :if={tget(e.details, "note")} class="text-xs text-base-content/50 italic">
                        {tget(e.details, "note")}
                      </p>
                      <p
                        :if={e.content_hash}
                        class="text-[0.65rem] font-mono text-base-content/40 truncate"
                        title={e.content_hash}
                      >
                        {String.slice(e.content_hash, 0, 16)}…
                      </p>
                    </div>
                  </li>
                </ol>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section :if={@profile.schedule} class="mt-6">
        <h2 class="text-xl font-semibold">{gettext("Repayment schedule")}</h2>
        <p :if={@profile.repayment_summary} class="text-sm text-base-content/70">
          {@profile.repayment_summary}
        </p>
        <div class="overflow-x-auto mt-2">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Due")}</th>
                <th>{gettext("Amount")}</th>
                <th>{gettext("Status")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- @profile.schedule.items}>
                <td>{item.due_on}</td>
                <td>{money(item.amount_cents, @profile.loan.currency_code, @locale)}</td>
                <td><span class="badge badge-sm badge-ghost">{status_label(item.status)}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp partner_path(%{loan: %{partner: %{slug: slug}}}) when is_binary(slug),
    do: ~p"/partners/#{slug}"

  defp partner_path(_), do: ~p"/loans"

  # --- Authenticity & provenance (staff/admin) --------------------------

  @prov_groups [
    photo: ~w(photo),
    identity: ~w(consent identity site_visit),
    story: ~w(story),
    translation: ~w(translation),
    listing: ~w(listing)
  ]

  defp staff_provenance(%{role: role}, loan_id) when role in ["staff", "admin"] do
    # Demo: the fabricated trail materializes on first staff view (1.1M loans
    # are not bulk-seeded); live command events append on top afterwards.
    fabrication = Kiva.Provenance.ensure_fabricated(loan_id)
    events = Kiva.Provenance.timeline(loan_id)
    chain = Kiva.Provenance.chain_status(events)

    groups =
      for {key, types} <- @prov_groups,
          evs = Enum.filter(events, &(&1.subject_type in types)),
          evs != [],
          do: {key, evs}

    %{
      events: events,
      chain: chain,
      groups: groups,
      fabrication_failed: fabrication == :error and events == [],
      broken: Enum.count(events, &(chain[&1.id] == :broken)),
      ai_reworded: Enum.any?(events, &(&1.event_type == "story.ai_reworded")),
      machine_translations: Enum.count(events, &(&1.event_type == "translation.machine")),
      photo_audience: photo_audience(events)
    }
  end

  defp staff_provenance(_, _), do: nil

  defp photo_audience(events) do
    events
    |> Enum.filter(&(&1.event_type == "photo.visibility_changed"))
    |> List.last()
    |> case do
      nil -> nil
      e -> tget(e.details, "to")
    end
  end

  # jsonb maps come back string-keyed after reload but atom-keyed on fresh
  # structs in tests — read both.
  defp tget(nil, _), do: nil
  defp tget(map, key), do: map[key] || map[String.to_atom(key)]

  defp group_label(:photo), do: gettext("Photo & capture")
  defp group_label(:identity), do: gettext("Identity, consent & site visit")
  defp group_label(:story), do: gettext("Story & authorship")
  defp group_label(:translation), do: gettext("Translations")
  defp group_label(:listing), do: gettext("Listing decisions")

  defp event_label("photo.captured"), do: gettext("Photo captured")
  defp event_label("photo.uploaded"), do: gettext("Photo uploaded")
  defp event_label("photo.reviewed"), do: gettext("Photo reviewed")
  defp event_label("photo.approved"), do: gettext("Photo approved")
  defp event_label("photo.visibility_changed"), do: gettext("Photo audience changed")
  defp event_label("consent.recorded"), do: gettext("Consent recorded")
  defp event_label("identity.verified"), do: gettext("Identity verified")
  defp event_label("site.visited"), do: gettext("Site visit")
  defp event_label("story.authored"), do: gettext("Story written")
  defp event_label("story.ai_reworded"), do: gettext("Story reworded by AI")
  defp event_label("story.reviewed"), do: gettext("Story reviewed")
  defp event_label("story.approved"), do: gettext("Story approved")
  defp event_label("translation.machine"), do: gettext("Machine translated")
  defp event_label("translation.template"), do: gettext("Template translated")
  defp event_label("translation.human"), do: gettext("Human translated")
  defp event_label("translation.reviewed"), do: gettext("Translation reviewed")
  defp event_label("translation.approved"), do: gettext("Translation approved")
  defp event_label("translation.rejected"), do: gettext("Translation rejected")
  defp event_label("listing.submitted"), do: gettext("Listing submitted")
  defp event_label("listing.approved"), do: gettext("Listing approved")
  defp event_label(other), do: other

  defp actor_icon("ai"), do: "hero-cpu-chip"
  defp actor_icon("system"), do: "hero-cog-6-tooth"
  defp actor_icon(_), do: "hero-user"

  defp tool_line(nil), do: nil
  defp tool_line(tool) when tool == %{}, do: nil

  defp tool_line(tool) do
    cond do
      app = tget(tool, "app") ->
        [app, tget(tool, "version") && "v#{tget(tool, "version")}", tget(tool, "device")]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" · ")

      model = tget(tool, "model") ->
        [model, tget(tool, "provider"), tget(tool, "template")]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" · ")

      template = tget(tool, "template") ->
        gettext("template") <> ": #{template}"

      true ->
        nil
    end
  end

  defp location_line(nil), do: nil

  defp location_line(loc) do
    place = tget(loc, "place")
    lat = tget(loc, "lat")
    lng = tget(loc, "lng")
    coords = lat && lng && "#{lat}, #{lng}"
    [place, coords] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")
  end
end
