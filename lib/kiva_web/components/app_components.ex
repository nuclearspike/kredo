defmodule KivaWeb.AppComponents do
  @moduledoc "Reusable Kiva-specific UI components."
  use Phoenix.Component
  use Gettext, backend: KivaWeb.Gettext
  use KivaWeb, :verified_routes

  import KivaWeb.CoreComponents, only: [icon: 1]
  import KivaWeb.ViewHelpers

  attr :item, :map, required: true, doc: "a localized loan card map from Kiva.Lending"
  attr :locale, :string, required: true

  @doc "Localized loan card with funding progress, trust model, and fallback flag."
  def loan_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/loans/#{@item.loan.slug}"}
      class="card bg-base-100 border border-base-200 hover:border-primary/50 hover:shadow-lg transition overflow-hidden group"
    >
      <div class="relative aspect-[3/2] overflow-hidden">
        <img
          :if={@item[:borrower_image]}
          src={@item.borrower_image}
          alt={@item.borrower_name}
          class="w-full h-full object-cover opacity-100 transition group-hover:scale-105"
        />
        <div
          :if={!@item[:borrower_image]}
          class="w-full h-full flex items-center justify-center bg-gradient-to-br from-primary/20 to-accent/20"
        >
          <span class="font-display text-6xl text-secondary/40">
            {String.first(@item.borrower_name || "K")}
          </span>
        </div>
        <span class="absolute top-2 left-2 badge badge-sm border-0 bg-base-100/90 text-base-content shadow-sm gap-1">
          <.icon name="hero-map-pin" class="size-3" /> {country_name(@item.loan.country_code)}
        </span>
        <span
          :if={@item.fallback_used}
          class="absolute top-2 right-2 badge badge-sm badge-warning border-0 gap-1"
          title={gettext("Showing a fallback language")}
        >
          <.icon name="hero-language" class="size-3" />{String.upcase(@item.resolved_locale || "en")}
        </span>
      </div>
      <div class="card-body p-4 gap-1.5">
        <span class="badge badge-sm badge-ghost w-fit">
          {trust_model_label(@item.loan.trust_model)}
        </span>
        <h3 class="card-title text-base leading-snug">{@item.title}</h3>
        <p class="text-sm text-base-content/70 line-clamp-2">{@item.short_description}</p>
        <p class="text-xs text-base-content/60">
          {@item.borrower_name} · {@item.sector_name}<span :if={@item.activity_name}> / {@item.activity_name}</span>
        </p>
        <p class="text-xs text-base-content/50 flex gap-3">
          <span :if={@item[:lenders_count] && @item.lenders_count > 0}>
            <.icon name="hero-users" class="size-3" /> {@item.lenders_count} {gettext("lenders")}
          </span>
          <span :if={days_left(@item.loan.fundraising_ends_at)} class="text-warning">
            <.icon name="hero-clock" class="size-3" /> {days_left(@item.loan.fundraising_ends_at)} {gettext(
              "days left"
            )}
          </span>
        </p>
        <.loan_status_line item={@item} locale={@locale} />
        <p class="text-primary text-sm font-semibold mt-1 flex items-center gap-1 group-hover:gap-2 transition-all">
          {gettext("Lend")} <.icon name="hero-arrow-right" class="size-3" />
        </p>
      </div>
    </.link>
    """
  end

  attr :item, :map, required: true, doc: "a localized loan card map from Kiva.Lending"
  attr :locale, :string, required: true

  attr :select_event, :string,
    default: nil,
    doc: "phx-click event to fire (with phx-value-slug) instead of navigating to the loan page."

  @doc """
  Horizontal (image-left) loan card for the Calm Forest browse grid. Navigates to
  the loan page by default; pass `select_event` to instead fire a click event (e.g.
  to open a details drawer) carrying the loan slug.
  """
  def loan_card_wide(assigns) do
    ~H"""
    <.link
      :if={is_nil(@select_event)}
      navigate={~p"/loans/#{@item.loan.slug}"}
      class="flex items-stretch bg-base-100 border border-base-200 rounded-2xl overflow-hidden hover:border-primary/40 hover:shadow-lg transition group"
    >
      <.loan_card_wide_body item={@item} locale={@locale} />
    </.link>
    <button
      :if={@select_event}
      type="button"
      phx-click={@select_event}
      phx-value-slug={@item.loan.slug}
      class="flex items-stretch text-left w-full bg-base-100 border border-base-200 rounded-2xl overflow-hidden hover:border-primary/40 hover:shadow-lg transition group cursor-pointer"
    >
      <.loan_card_wide_body item={@item} locale={@locale} />
    </button>
    """
  end

  attr :item, :map, required: true
  attr :locale, :string, required: true

  defp loan_card_wide_body(assigns) do
    ~H"""
    <div class={[
      "relative w-2/5 min-w-[8rem] shrink-0 overflow-hidden",
      !@item[:borrower_image] && card_pattern(@item)
    ]}>
      <img
        :if={@item[:borrower_image]}
        src={@item.borrower_image}
        alt={@item.borrower_name}
        class="absolute inset-0 w-full h-full object-cover opacity-100 transition duration-300 group-hover:scale-105"
      />
      <div
        :if={!@item[:borrower_image]}
        class="absolute inset-0 flex items-center justify-center font-display text-7xl text-secondary/40"
      >
        {String.first(@item.borrower_name || "K")}
      </div>
      <span class="absolute top-3 left-3 z-10 inline-flex items-center gap-1 rounded-full bg-base-100/90 px-2 py-1 text-xs font-medium shadow-sm">
        {country_flag(@item.loan.country_code)} {country_name(@item.loan.country_code)}
      </span>
    </div>
    <div class="flex flex-col flex-1 min-w-0 p-5 gap-1.5">
      <span class="badge badge-sm border-0 bg-success/10 text-success uppercase tracking-wide text-[0.65rem] font-semibold w-fit">
        {trust_model_label(@item.loan.trust_model)}
      </span>
      <h3 class="font-display text-xl font-semibold text-secondary leading-tight">{@item.title}</h3>
      <p class="text-sm text-base-content/70 line-clamp-2">{@item.short_description}</p>
      <p class="text-xs text-base-content/55">
        {@item.borrower_name} · {@item.sector_name}<span :if={@item.activity_name}> / {@item.activity_name}</span>
      </p>
      <.loan_status_line item={@item} locale={@locale} />
      <p class="text-xs text-base-content/50 flex gap-3 mt-0.5">
        <span :if={@item[:lenders_count] && @item.lenders_count > 0}>
          {@item.lenders_count} {gettext("lenders")}
        </span>
        <span :if={days_left(@item.loan.fundraising_ends_at)} class="text-warning">
          {days_left(@item.loan.fundraising_ends_at)} {gettext("days left")}
        </span>
      </p>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :locale, :string, required: true

  @doc "Funding bar for fundraising loans; a status badge for every later lifecycle state."
  def loan_status_line(assigns) do
    ~H"""
    <.funding_bar :if={@item.loan.status == "fundraising"} item={@item} locale={@locale} />
    <div :if={@item.loan.status != "fundraising"} class="flex items-center justify-between mt-1">
      <span class={["badge badge-sm border-0 font-medium", loan_status_color(@item.loan.status)]}>
        {loan_status_label(@item.loan.status)}
      </span>
      <span class="text-xs text-base-content/60">
        {money(@item.loan.loan_amount_cents, @item.loan.currency_code, @locale)}
      </span>
    </div>
    """
  end

  attr :item, :map,
    required: true,
    doc: "a localized loan profile/card map with `.loan` and `.repayment`."

  attr :locale, :string, required: true

  @doc "Post-fundraising repayment progress: paid installments, amounts, and a success bar."
  def repayment_progress(assigns) do
    ~H"""
    <div :if={@item[:repayment] && @item.repayment.total_count > 0}>
      <div class="text-sm">
        {gettext("Repaid")}: {@item.repayment.paid_count}/{@item.repayment.total_count} · {money(
          @item.repayment.paid_cents,
          @item.loan.currency_code,
          @locale
        )} {gettext("of")} {money(@item.repayment.total_cents, @item.loan.currency_code, @locale)}
      </div>
      <progress
        class="progress progress-success w-full"
        value={@item.repayment.paid_count}
        max={@item.repayment.total_count}
      >
      </progress>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :locale, :string, required: true

  @doc "Funding progress bar with localized amounts."
  def funding_bar(assigns) do
    ~H"""
    <div>
      <progress class="progress progress-primary w-full" value={@item.funded_percent} max="100">
      </progress>
      <div class="flex justify-between text-xs mt-1">
        <span class="font-semibold">
          {money(@item.loan.funded_amount_cents, @item.loan.currency_code, @locale)}
        </span>
        <span class="text-base-content/60">
          {gettext("of")} {money(@item.loan.loan_amount_cents, @item.loan.currency_code, @locale)} · {@item.funded_percent}%
        </span>
      </div>
    </div>
    """
  end

  attr :profile, :map,
    default: nil,
    doc: "a localized loan profile (from get_localized_loan/2), or nil."

  attr :open, :boolean, default: false
  attr :locale, :string, required: true

  attr :can_lend, :boolean,
    default: false,
    doc: "current user is a lender (shows the lend controls)."

  attr :amount, :string, default: "2500", doc: "selected lend amount in cents."

  @doc """
  Right-side loan-details drawer. Slides in over the page with a summary of a loan
  and a link to its full page. Expects the host LiveView to handle a `close_drawer`
  event. Kept in the DOM so it can animate; content renders only when `profile` is set.
  """
  def loan_drawer(assigns) do
    ~H"""
    <div
      id="loan-drawer"
      class={[
        "fixed inset-0 z-50 m-0 transition-opacity duration-300",
        (@open && "opacity-100 pointer-events-auto") || "opacity-0 pointer-events-none"
      ]}
      aria-hidden={!@open}
    >
      <div class="absolute inset-0 bg-black/40" phx-click="close_drawer"></div>
      <aside
        phx-window-keydown="close_drawer"
        phx-key="Escape"
        class={[
          "absolute right-0 top-0 h-full w-full max-w-md bg-base-100 shadow-2xl flex flex-col transition-transform duration-300 ease-out",
          (@open && "translate-x-0") || "translate-x-full"
        ]}
      >
        <div :if={@profile} class="flex flex-col h-full">
          <div class="flex items-center justify-end gap-1 px-3 py-2 border-b border-base-200">
            <.link
              navigate={~p"/loans/#{@profile.loan.slug}"}
              class="btn btn-ghost btn-sm btn-circle"
              title={gettext("Open full page")}
            >
              <.icon name="hero-arrow-top-right-on-square" class="size-5" />
            </.link>
            <button
              type="button"
              phx-click="close_drawer"
              class="btn btn-ghost btn-sm btn-circle"
              aria-label={gettext("Close")}
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <div class="flex-1 overflow-y-auto px-5 py-4 space-y-4">
            <div class={[
              "relative aspect-[3/2] rounded-2xl overflow-hidden",
              !@profile[:borrower_image] && card_pattern(@profile)
            ]}>
              <img
                :if={@profile[:borrower_image]}
                src={@profile.borrower_image}
                alt={@profile.borrower_name}
                class="absolute inset-0 w-full h-full object-cover"
              />
              <div
                :if={!@profile[:borrower_image]}
                class="absolute inset-0 flex items-center justify-center font-display text-7xl text-secondary/40"
              >
                {String.first(@profile.borrower_name || "K")}
              </div>
              <span class="absolute bottom-3 left-3 inline-flex items-center gap-1 rounded-full bg-base-100/90 px-2.5 py-1 text-sm font-medium shadow-sm">
                {country_flag(@profile.loan.country_code)} {country_name(@profile.loan.country_code)}
              </span>
            </div>

            <div>
              <h2 class="font-display text-2xl font-semibold text-secondary leading-tight">
                {@profile.title}
              </h2>
              <p class="text-sm text-base-content/60 mt-0.5">{@profile.borrower_name}</p>
              <div class="flex flex-wrap gap-x-3 gap-y-0.5 text-success font-medium text-sm mt-1">
                <span>{@profile.sector_name}</span>
                <span :if={@profile.activity_name}>{@profile.activity_name}</span>
              </div>
            </div>

            <div :if={fundraising?(@profile)}>
              <.funding_bar item={@profile} locale={@locale} />
              <div class="flex justify-between items-end mt-2">
                <div :if={days_left(@profile.loan.fundraising_ends_at)}>
                  <span class="font-display text-xl font-semibold">
                    {days_left(@profile.loan.fundraising_ends_at)} {gettext("days")}
                  </span>
                  <span class="block text-xs uppercase tracking-wide text-base-content/50">
                    {gettext("Remaining")}
                  </span>
                </div>
                <div class="text-right ml-auto">
                  <span class="font-display text-xl font-semibold">
                    {money(
                      max(@profile.loan.loan_amount_cents - @profile.loan.funded_amount_cents, 0),
                      @profile.loan.currency_code,
                      @locale
                    )} {gettext("to go")}
                  </span>
                  <span class="block text-xs uppercase tracking-wide text-base-content/50">
                    {@profile.funded_percent}% {gettext("Funded")}
                  </span>
                </div>
              </div>
            </div>

            <.repayment_progress :if={!fundraising?(@profile)} item={@profile} locale={@locale} />

            <div :if={@profile.loan_use} class="border-l-4 border-success/40 pl-3">
              <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                {gettext("How this money helps")}
              </p>
              <p class="mt-1">{@profile.loan_use}</p>
            </div>

            <div :if={@profile.borrower_story}>
              <p class="whitespace-pre-line text-base-content/80 line-clamp-6">
                {@profile.borrower_story}
              </p>
            </div>

            <div class="flex flex-wrap gap-x-6 gap-y-2 pt-1">
              <div>
                <p class="text-xs uppercase tracking-wide text-base-content/50">
                  {gettext("Loan amount")}
                </p>
                <p class="font-semibold">
                  {money(@profile.loan.loan_amount_cents, @profile.loan.currency_code, @locale)}
                </p>
              </div>
              <div :if={@profile.loan.repayment_term_months}>
                <p class="text-xs uppercase tracking-wide text-base-content/50">{gettext("Term")}</p>
                <p class="font-semibold">{@profile.loan.repayment_term_months} {gettext("months")}</p>
              </div>
              <div>
                <p class="text-xs uppercase tracking-wide text-base-content/50">
                  {gettext("Trust model")}
                </p>
                <p class="font-semibold">{trust_model_label(@profile.loan.trust_model)}</p>
              </div>
            </div>
          </div>

          <div class="px-4 py-3 border-t border-base-200 space-y-2">
            <div :if={!lendable?(@profile)} class="text-center text-sm text-base-content/60">
              <span class={[
                "badge badge-sm border-0 font-medium mr-1",
                loan_status_color(@profile.loan.status)
              ]}>
                {loan_status_label(@profile.loan.status)}
              </span>
              {gettext("Lending is closed for this loan.")}
            </div>
            <div :if={@can_lend && lendable?(@profile)} class="flex items-center gap-2">
              <button
                :for={{cents, label} <- [{"2500", "$25"}, {"5000", "$50"}, {"7500", "$75"}]}
                type="button"
                phx-click="set_drawer_amount"
                phx-value-cents={cents}
                class={[
                  "btn btn-sm flex-1",
                  (@amount == cents && "btn-primary") || "btn-outline border-base-300"
                ]}
              >
                {label}
              </button>
              <div class="dropdown dropdown-top dropdown-end">
                <label
                  tabindex="0"
                  class={[
                    "btn btn-sm gap-1",
                    (@amount not in ["2500", "5000", "7500"] && "btn-primary") ||
                      "btn-outline border-base-300"
                  ]}
                >
                  {gettext("Other")} <.icon name="hero-chevron-down" class="size-3" />
                </label>
                <ul
                  tabindex="0"
                  class="dropdown-content menu bg-base-100 rounded-box z-10 w-32 p-2 shadow border border-base-200"
                >
                  <li :for={
                    {cents, label} <- [
                      {"10000", "$100"},
                      {"15000", "$150"},
                      {"25000", "$250"},
                      {"50000", "$500"}
                    ]
                  }>
                    <button type="button" phx-click="set_drawer_amount" phx-value-cents={cents}>
                      {label}
                    </button>
                  </li>
                </ul>
              </div>
            </div>

            <button
              :if={@can_lend && lendable?(@profile)}
              type="button"
              phx-click="drawer_support"
              class="btn btn-primary w-full"
            >
              <.icon name="hero-heart" class="size-4" /> {gettext("Support")} {@profile.borrower_name}
            </button>
            <.link
              :if={!@can_lend && lendable?(@profile)}
              href={~p"/login"}
              class="btn btn-primary w-full"
            >
              <.icon name="hero-heart" class="size-4" /> {gettext("Support")} {@profile.borrower_name}
            </.link>

            <.link
              navigate={~p"/loans/#{@profile.loan.slug}"}
              class="block text-center text-sm text-base-content/60 hover:text-primary"
            >
              {gettext("View full loan page")} →
            </.link>
          </div>
        </div>
      </aside>
    </div>
    """
  end

  # New lending is only offered while the loan is fundraising.
  defp lendable?(profile), do: Kiva.Lending.Loan.lendable?(profile.loan)

  # Stage predicate for display: funding progress vs repayment progress.
  defp fundraising?(profile), do: Kiva.Lending.Loan.fundraising?(profile.loan)

  attr :icon, :string, default: "hero-sparkles"
  attr :title, :string, required: true
  attr :body, :string, required: true

  @doc "A centered placeholder block for not-yet-built pages."
  def placeholder(assigns) do
    ~H"""
    <div class="hero bg-base-200 rounded-box py-16">
      <div class="hero-content text-center">
        <div class="max-w-md">
          <.icon name={@icon} class="size-12 text-primary mx-auto" />
          <h1 class="text-2xl font-bold mt-4">{@title}</h1>
          <p class="mt-2 text-base-content/70">{@body}</p>
        </div>
      </div>
    </div>
    """
  end
end
