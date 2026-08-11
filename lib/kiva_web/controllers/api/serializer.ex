defmodule KivaWeb.Api.Serializer do
  @moduledoc """
  Shared JSON shaping for the public API.

  Single source of truth for the borrower-image privacy rule: a borrower's photo
  is only exposed while the loan is still fundraising. Once a loan is funded (or
  anything past fundraising) the image is omitted. Both the REST controllers and
  the GraphQL loan-card resolver route through `borrower_image/2`.
  """

  @doc "Borrower image, gated by loan status. nil unless the loan is fundraising."
  def borrower_image("fundraising", image_url), do: image_url
  def borrower_image(_status, _image_url), do: nil

  def loan_card(c) do
    %{
      id: c.loan.id,
      slug: c.loan.slug,
      title: c.title,
      short_description: c.short_description,
      borrower_name: c.borrower_name,
      borrower_image: borrower_image(c.loan.status, Map.get(c, :borrower_image)),
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

  def loan_profile(p) do
    p
    |> loan_card()
    |> Map.merge(%{
      borrower_story: p.borrower_story,
      loan_use: p.loan_use,
      risk_summary_public: p.risk_summary_public,
      repayment_summary: p.repayment_summary,
      disbursal_status: p.loan.disbursal_status,
      repayment_term_months: p.loan.repayment_term_months
    })
  end

  def partner(p) do
    %{
      slug: p.partner.slug,
      name: p.name,
      summary: p.summary,
      profile: p.profile,
      country_code: p.partner.country_code,
      trust_model: p.partner.trust_model,
      resolved_locale: p.resolved_locale,
      fallback_used: p.fallback_used
    }
  end

  def team_card(t) do
    %{
      slug: t.team.slug,
      name: t.name,
      tagline: t.tagline,
      description: t.description,
      visibility: t.team.visibility,
      image_url: t.team.image_url,
      member_count: t.team.member_count,
      total_lent_cents: t.team.total_lent_cents,
      resolved_locale: t.resolved_locale,
      fallback_used: t.fallback_used
    }
  end

  def team_detail(t) do
    t
    |> team_card()
    |> Map.merge(%{
      member_count: t.member_count,
      posts: Enum.map(t.posts, &team_post/1)
    })
  end

  defp team_post(p) do
    %{
      body: p.body,
      author_name: p.author_name,
      author_role: p.author_role,
      captain: p.captain?,
      posted_at: p.posted_at
    }
  end

  def faq(f) do
    %{
      slug: f.faq.slug,
      question: f.lc && f.lc.question,
      answer: f.lc && f.lc.answer,
      resolved_locale: f.resolved_locale,
      fallback_used: f.fallback_used,
      status: f.status
    }
  end

  def user(u) do
    %{
      id: u.id,
      email: u.email,
      display_name: u.display_name,
      role: u.role,
      default_locale_code: u.default_locale_code,
      avatar_url: u.avatar_url
    }
  end
end
