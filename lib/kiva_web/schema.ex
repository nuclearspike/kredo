defmodule KivaWeb.Schema do
  @moduledoc """
  Role-scoped GraphQL surface. Public queries are open; lender/borrower/partner
  /staff/admin queries are gated by `Authorize` middleware against the actor role
  in context. The page-aware AI asks and explains through these queries only.
  """
  use Absinthe.Schema

  alias KivaWeb.Resolvers
  alias KivaWeb.Schema.Middleware.Authorize

  object :viewer do
    field :role, :string
    field :locale, :string
    field :display_name, :string
  end

  object :loan_card do
    field :slug, :string
    field :title, :string
    field :short_description, :string
    field :borrower_name, :string
    @desc "Borrower photo — only present while the loan is fundraising; null after."
    field :borrower_image, :string
    field :partner_name, :string
    field :sector_name, :string
    field :country_code, :string
    field :trust_model, :string
    field :status, :string
    field :loan_amount_cents, :integer
    field :funded_amount_cents, :integer
    field :currency_code, :string
    field :funded_percent, :integer
    field :resolved_locale, :string
    field :fallback_used, :boolean
  end

  object :loan_profile do
    import_fields(:loan_card)
    field :borrower_story, :string
    field :loan_use, :string
    field :risk_summary_public, :string
    field :repayment_summary, :string
    field :disbursal_status, :string
    field :repayment_term_months, :integer
  end

  object :partner_profile do
    field :slug, :string
    field :name, :string
    field :summary, :string
    field :profile, :string
    field :country_code, :string
    field :trust_model, :string
    field :resolved_locale, :string
    field :fallback_used, :boolean
  end

  object :faq_entry do
    field :slug, :string
    field :question, :string
    field :answer, :string
    field :resolved_locale, :string
    field :fallback_used, :boolean
    field :status, :string
  end

  object :permission_outlier do
    field :email, :string
    field :role, :string
    field :permission, :string
    field :risk, :string
  end

  object :audit_event do
    field :id, :id
    field :event_type, :string
    field :summary, :string
    field :actor_role, :string
    field :target_type, :string
    field :target_id, :string
    field :inserted_at, :string
  end

  # --- authenticated viewer ("me") ---
  object :lending do
    field :loan_slug, :string
    field :loan_title, :string
    field :status, :string
    field :funded_percent, :integer
    field :amount_cents, :integer
    field :lending_team_id, :integer
  end

  object :team_membership do
    field :id, :integer
    field :name, :string
  end

  object :portfolio_summary do
    field :count, :integer
    field :total_cents, :integer
    field :returned_cents, :integer
    field :available_to_relend_cents, :integer
  end

  @desc "The authenticated user's own data — the same loans, teams, and portfolio they see when logged in."
  object :me do
    field :id, :id
    field :email, :string
    field :display_name, :string
    field :role, :string
    field :default_locale_code, :string
    field :avatar_url, :string

    @desc "Loans this user has funded."
    field :lendings, list_of(:lending), resolve: &Resolvers.me_lendings/3

    @desc "Teams this user belongs to."
    field :teams, list_of(:team_membership), resolve: &Resolvers.me_teams/3

    @desc "Loans this user owns as a borrower (empty for non-borrowers)."
    field :borrower_loans, list_of(:loan_profile), resolve: &Resolvers.me_borrower_loans/3

    @desc "Lender portfolio totals."
    field :portfolio, :portfolio_summary, resolve: &Resolvers.me_portfolio/3
  end

  query do
    @desc "The current actor (role + locale)."
    field :viewer, :viewer, resolve: &Resolvers.viewer/3

    @desc "Authenticated: the current user's own loans, teams, and portfolio."
    field :me, :me, resolve: &Resolvers.me/3

    @desc "Public: localized loan search."
    field :localized_loans, list_of(:loan_card) do
      arg(:locale, :string)
      arg(:sector_id, :integer)
      arg(:country_code, :string)
      arg(:trust_model, :string)
      arg(:q, :string)
      resolve(&Resolvers.localized_loans/3)
    end

    @desc "Public: localized loan profile by slug."
    field :localized_loan, :loan_profile do
      arg(:slug, non_null(:string))
      arg(:locale, :string)
      resolve(&Resolvers.localized_loan/3)
    end

    @desc "Public: localized partner profile by slug."
    field :localized_partner, :partner_profile do
      arg(:slug, non_null(:string))
      arg(:locale, :string)
      resolve(&Resolvers.localized_partner/3)
    end

    @desc "Public: localized FAQ entries."
    field :faq_entries, list_of(:faq_entry) do
      arg(:locale, :string)
      resolve(&Resolvers.faq_entries/3)
    end

    @desc "Staff/admin: count of loans awaiting review."
    field :staff_review_queue_count, :integer do
      middleware(Authorize, ["staff", "admin"])
      resolve(&Resolvers.staff_review_queue_count/3)
    end

    @desc "Admin only: recent audit events."
    field :audit_events, list_of(:audit_event) do
      arg(:limit, :integer)
      middleware(Authorize, ["admin"])
      resolve(&Resolvers.audit_events/3)
    end

    @desc "Staff/admin: loans awaiting review."
    field :loan_review_queue, list_of(:loan_card) do
      middleware(Authorize, ["staff", "admin"])
      resolve(&Resolvers.loan_review_queue/3)
    end

    @desc "Admin only: permission outliers (direct grants beyond role groups)."
    field :permission_outliers, list_of(:permission_outlier) do
      middleware(Authorize, ["admin"])
      resolve(&Resolvers.permission_outliers/3)
    end
  end
end
