defmodule Kiva.Lending.Loan do
  use Ecto.Schema
  import Ecto.Changeset

  @trust_models ~w(partner_facilitated direct trustee_backed social_underwritten blockchain_attested hybrid)
  @disbursal ~w(pre_disbursed post_disbursed direct_disbursal_pending direct_disbursed)

  @derive {Phoenix.Param, key: :slug}
  schema "loans" do
    field :slug, :string
    field :status, :string, default: "fundraising"
    field :country_code, :string
    field :trust_model, :string, default: "partner_facilitated"
    field :loan_amount_cents, :integer, default: 0
    field :funded_amount_cents, :integer, default: 0
    field :currency_code, :string, default: "USD"
    field :disbursal_status, :string, default: "pre_disbursed"
    field :disbursed_at, :utc_datetime
    field :fundraising_started_at, :utc_datetime
    field :fundraising_ends_at, :utc_datetime
    field :repayment_term_months, :integer
    field :repayment_frequency, :string, default: "monthly"
    field :source_locale_code, :string, default: "en"
    field :changes_requested_reason, :string

    belongs_to :partner, Kiva.Partners.Partner
    belongs_to :borrower, Kiva.Borrowers.Borrower
    belongs_to :sector, Kiva.Taxonomy.Sector
    belongs_to :activity, Kiva.Taxonomy.Activity
    has_many :translations, Kiva.Lending.LoanLc, foreign_key: :loan_id
    has_one :repayment_schedule, Kiva.Lending.RepaymentSchedule, foreign_key: :loan_id
    timestamps(type: :utc_datetime)
  end

  def trust_models, do: @trust_models
  def disbursal_statuses, do: @disbursal

  @doc "True while the loan is in its fundraising stage (drives stage-aware display)."
  def fundraising?(%__MODULE__{status: status}), do: status == "fundraising"

  @doc "Only fundraising loans accept new lending (basket adds and lends)."
  def lendable?(%__MODULE__{} = loan), do: fundraising?(loan)

  def changeset(loan, attrs) do
    loan
    |> cast(attrs, [
      :slug,
      :status,
      :country_code,
      :trust_model,
      :loan_amount_cents,
      :funded_amount_cents,
      :currency_code,
      :disbursal_status,
      :disbursed_at,
      :fundraising_started_at,
      :fundraising_ends_at,
      :repayment_term_months,
      :repayment_frequency,
      :source_locale_code,
      :partner_id,
      :borrower_id,
      :sector_id,
      :activity_id
    ])
    |> validate_required([:slug, :loan_amount_cents, :currency_code])
    |> validate_inclusion(:trust_model, @trust_models)
    |> Kiva.Money.validate_lend_amount(:loan_amount_cents, allow_zero: true)
    |> Kiva.Money.validate_lend_amount(:funded_amount_cents, allow_zero: true)
    |> unique_constraint(:slug)
  end
end
