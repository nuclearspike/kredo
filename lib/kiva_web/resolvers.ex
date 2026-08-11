defmodule KivaWeb.Resolvers do
  @moduledoc "Resolvers for the role-scoped GraphQL surfaces."
  alias Kiva.{Lending, Partners, Content, Audit}

  defp locale(args, ctx), do: args[:locale] || ctx[:locale] || "en"

  def viewer(_p, _a, %{context: ctx}) do
    {:ok,
     %{
       role: ctx[:actor_role] || "public",
       locale: ctx[:locale] || "en",
       display_name: ctx[:current_user] && ctx[:current_user].display_name
     }}
  end

  # --- authenticated viewer ("me") ---
  def me(_p, _a, %{context: %{current_user: nil}}),
    do: {:error, "unauthorized: requires authentication"}

  def me(_p, _a, %{context: %{current_user: user}}) when not is_nil(user), do: {:ok, user}
  def me(_p, _a, _res), do: {:error, "unauthorized: requires authentication"}

  def me_lendings(user, _a, %{context: ctx}),
    do: {:ok, Kiva.Portfolio.list_user_lendings_localized(user.id, ctx[:locale] || "en")}

  def me_teams(user, _a, %{context: ctx}),
    do: {:ok, Kiva.Teams.list_user_teams(user.id, ctx[:locale] || "en")}

  def me_borrower_loans(user, _a, %{context: ctx}) do
    case Kiva.Borrowers.get_by_user(user.id) do
      nil ->
        {:ok, []}

      b ->
        {:ok,
         Kiva.Lending.list_loans_for_borrower(b.id, ctx[:locale] || "en") |> Enum.map(&profile/1)}
    end
  end

  def me_portfolio(user, _a, _res) do
    summary = Kiva.Portfolio.portfolio_summary(user.id)
    {:ok, Map.take(summary, [:count, :total_cents, :returned_cents, :available_to_relend_cents])}
  end

  def localized_loans(_p, args, %{context: ctx}) do
    filters =
      %{}
      |> maybe(:sector_id, args[:sector_id])
      |> maybe(:country_code, args[:country_code])
      |> maybe(:trust_model, args[:trust_model])
      |> maybe(:q, args[:q])

    {:ok, Lending.list_localized_loans(locale(args, ctx), filters) |> Enum.map(&card/1)}
  end

  def localized_loan(_p, args, %{context: ctx}) do
    case Lending.get_localized_loan(args.slug, locale(args, ctx)) do
      nil -> {:error, "not_found"}
      profile -> {:ok, profile(profile)}
    end
  end

  def localized_partner(_p, args, %{context: ctx}) do
    case Partners.get_localized_partner(args.slug, locale(args, ctx)) do
      nil ->
        {:error, "not_found"}

      p ->
        {:ok,
         %{
           slug: p.partner.slug,
           name: p.name,
           summary: p.summary,
           profile: p.profile,
           country_code: p.partner.country_code,
           trust_model: p.partner.trust_model,
           resolved_locale: p.resolved_locale,
           fallback_used: p.fallback_used
         }}
    end
  end

  def faq_entries(_p, args, %{context: ctx}) do
    entries =
      Content.list_localized_faqs(locale(args, ctx))
      |> Enum.map(fn item ->
        %{
          slug: item.faq.slug,
          question: item.lc && item.lc.question,
          answer: item.lc && item.lc.answer,
          resolved_locale: item.resolved_locale,
          fallback_used: item.fallback_used,
          status: item.status
        }
      end)

    {:ok, entries}
  end

  # --- role-scoped (enforced by middleware) ---
  def audit_events(_p, args, _res) do
    {:ok,
     Audit.list_events(args[:limit] || 50)
     |> Enum.map(fn e ->
       %{
         id: e.id,
         event_type: e.event_type,
         summary: e.summary,
         actor_role: e.actor_role,
         target_type: e.target_type,
         target_id: e.target_id,
         inserted_at: e.inserted_at && DateTime.to_iso8601(e.inserted_at)
       }
     end)}
  end

  def staff_review_queue_count(_p, _a, _res), do: {:ok, Lending.review_queue_count()}

  def loan_review_queue(_p, _a, %{context: ctx}),
    do: {:ok, Lending.review_queue(ctx[:locale] || "en") |> Enum.map(&card/1)}

  def permission_outliers(_p, _a, _res), do: {:ok, Kiva.Permissions.list_outliers()}

  # --- mappers ---
  defp card(c) do
    %{
      slug: c.loan.slug,
      title: c.title,
      short_description: c.short_description,
      borrower_name: c.borrower_name,
      borrower_image:
        KivaWeb.Api.Serializer.borrower_image(c.loan.status, Map.get(c, :borrower_image)),
      partner_name: c.partner_name,
      sector_name: c.sector_name,
      country_code: c.loan.country_code,
      trust_model: c.loan.trust_model,
      status: c.loan.status,
      loan_amount_cents: c.loan.loan_amount_cents,
      funded_amount_cents: c.loan.funded_amount_cents,
      currency_code: c.loan.currency_code,
      funded_percent: c.funded_percent,
      resolved_locale: c.resolved_locale,
      fallback_used: c.fallback_used
    }
  end

  defp profile(p) do
    p
    |> card()
    |> Map.merge(%{
      borrower_story: p.borrower_story,
      loan_use: p.loan_use,
      risk_summary_public: p.risk_summary_public,
      repayment_summary: p.repayment_summary,
      disbursal_status: p.loan.disbursal_status,
      repayment_term_months: p.loan.repayment_term_months
    })
  end

  defp maybe(map, _k, nil), do: map
  defp maybe(map, _k, ""), do: map
  defp maybe(map, k, v), do: Map.put(map, k, v)
end
