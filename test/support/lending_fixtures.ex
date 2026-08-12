defmodule Kiva.LendingFixtures do
  @moduledoc "Builds a fully-localized loan (sector/partner/borrower/loan + LC rows)."
  import Ecto.Query
  alias Kiva.{Taxonomy, Partners, Lending, Repo}
  alias Kiva.Borrowers.{Borrower, BorrowerLc}

  @doc """
  A seeded loan, complete with a repayment schedule.

  Pass `schedule: false` for a loan that has never been given one — the state a
  loan is in when it is created and disbursed at runtime rather than seeded.
  """
  def loan_fixture(attrs \\ %{}, opts \\ []) do
    sector = Taxonomy.upsert_sector("arts")

    Taxonomy.upsert_sector_lc(%{
      sector_id: sector.id,
      locale_code: "en",
      name: "Arts",
      is_source: true,
      source_locale_code: "en",
      translation_status: "published"
    })

    Taxonomy.upsert_sector_lc(%{
      sector_id: sector.id,
      locale_code: "es",
      name: "Artes",
      source_locale_code: "en",
      translation_status: "approved"
    })

    partner =
      Partners.upsert_partner(%{
        slug: "p-#{uniq()}",
        country_code: "GT",
        trust_model: "partner_facilitated",
        status: "active"
      })

    Partners.upsert_partner_lc(%{
      partner_id: partner.id,
      locale_code: "en",
      name: "Loom Co",
      is_source: true,
      source_locale_code: "en",
      translation_status: "published"
    })

    {:ok, borrower} =
      %Borrower{}
      |> Borrower.changeset(%{
        public_id: "b-#{uniq()}",
        country_code: "GT",
        preferred_locale_code: "es",
        partner_id: partner.id,
        sector_id: sector.id
      })
      |> Repo.insert()

    Repo.insert!(
      BorrowerLc.changeset(%BorrowerLc{}, %{
        borrower_id: borrower.id,
        locale_code: "en",
        display_name: "Rosa",
        is_source: true,
        source_locale_code: "en",
        translation_status: "published"
      })
    )

    slug = attrs[:slug] || "loan-#{uniq()}"

    loan =
      Lending.upsert_loan(
        Map.merge(
          %{
            slug: slug,
            status: "fundraising",
            partner_id: partner.id,
            borrower_id: borrower.id,
            country_code: "GT",
            sector_id: sector.id,
            trust_model: "partner_facilitated",
            disbursal_status: "pre_disbursed",
            loan_amount_cents: 100_000,
            funded_amount_cents: 40_000,
            currency_code: "USD",
            repayment_term_months: 8,
            source_locale_code: "en"
          },
          attrs
        )
      )

    Lending.upsert_loan_lc(%{
      loan_id: loan.id,
      locale_code: "en",
      is_source: true,
      source_locale_code: "en",
      title: "Weaving loan",
      short_description: "Buy thread",
      borrower_story: "Rosa weaves textiles",
      loan_use: "thread",
      repayment_summary: "monthly",
      risk_summary_public: "low risk",
      translation_status: "published"
    })

    Lending.upsert_loan_lc(%{
      loan_id: loan.id,
      locale_code: "es",
      is_source: false,
      source_locale_code: "en",
      title: "Préstamo de tejido",
      short_description: "Comprar hilo",
      borrower_story: "Rosa teje textiles",
      loan_use: "hilo",
      repayment_summary: "mensual",
      risk_summary_public: "riesgo bajo",
      translation_status: "approved"
    })

    if Keyword.get(opts, :schedule, true) do
      Lending.create_repayment_schedule(loan.id, ~D[2026-07-01], 8, 12_500)
    end

    %{loan: loan, sector: sector, partner: partner, borrower: borrower}
  end

  @doc "A partner User linked to a partner org that already has a borrower + prior loan."
  def partner_user_fixture do
    base = loan_fixture()

    {:ok, user} =
      Kiva.Accounts.register_user(%{
        email: "partner-#{uniq()}@kredo.test",
        password: "password",
        role: "partner"
      })

    user = Kiva.Accounts.set_managed_partner(user, base.partner.id)
    Map.merge(base, %{user: user})
  end

  @doc "A borrower User linked to a borrower record (preferred locale es) with a loan."
  def borrower_user_fixture do
    base = loan_fixture()

    {:ok, user} =
      Kiva.Accounts.register_user(%{
        email: "borrower-#{uniq()}@kredo.test",
        password: "password",
        role: "borrower"
      })

    {:ok, borrower} =
      base.borrower
      |> Kiva.Borrowers.Borrower.changeset(%{user_id: user.id})
      |> Kiva.Repo.update()

    Map.merge(base, %{user: user, borrower: borrower})
  end

  @doc "A partner-submitted loan in the staff review queue, plus a staff user."
  def submitted_loan_fixture do
    base = partner_user_fixture()
    draft = Kiva.LoanApplications.create_or_resume_draft(base.partner.id, base.borrower.id)

    Kiva.Commands.execute("save_loan_draft", base.user, %{
      "loan_draft_id" => draft.id,
      "amount" => "500",
      "term" => "8",
      "sector_id" => to_string(base.sector.id),
      "title" => "Submit me",
      "borrower_story" => "Story",
      "loan_use" => "Use",
      "risk_summary_public" => "Low risk"
    })

    {:ok, _} =
      Kiva.Commands.execute("submit_loan_for_review", base.user, %{"loan_draft_id" => draft.id})

    {:ok, staff} =
      Kiva.Accounts.register_user(%{
        email: "staff-#{uniq()}@kredo.test",
        password: "password",
        role: "staff"
      })

    Map.merge(base, %{draft: draft, staff: staff})
  end

  @doc """
  Give a loan a reviewed translation in every supported language, which is what
  the translation review queue produces for a real listing. Publishing is gated
  on it, so any test that approves a listing needs this first.
  """
  def translate_fully(loan) do
    src =
      Repo.one!(from lc in Kiva.Lending.LoanLc, where: lc.loan_id == ^loan.id and lc.is_source)

    for locale <- Kiva.Localization.supported_locales(), locale != src.locale_code do
      Lending.upsert_loan_lc(%{
        loan_id: loan.id,
        locale_code: locale,
        is_source: false,
        source_locale_code: src.locale_code,
        title: src.title,
        short_description: src.short_description,
        borrower_story: src.borrower_story,
        loan_use: src.loan_use,
        repayment_summary: src.repayment_summary,
        risk_summary_public: src.risk_summary_public,
        translation_status: "approved"
      })
    end

    loan
  end

  defp uniq, do: System.unique_integer([:positive])
end
