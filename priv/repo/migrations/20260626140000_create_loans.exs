defmodule Kiva.Repo.Migrations.CreateLoans do
  use Ecto.Migration

  # Lean *_lc column set used by loan/partner/borrower/taxonomy sidecars.
  # Called inside a `create table do ... end` block where `add`/`timestamps`
  # register columns on the table currently being built.
  defp add_lc_common do
    add :locale_code, :string, null: false
    add :is_source, :boolean, null: false, default: false
    add :source_locale_code, :string
    add :translation_status, :string, null: false, default: "draft"
    add :translated_from_lc_id, :integer
    add :version, :integer, null: false, default: 1
    add :source_hash, :string
    timestamps(type: :utc_datetime)
  end

  def change do
    # --- Taxonomy ---
    create table(:sectors) do
      add :key, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:sectors, [:key])

    create table(:sectors_lc) do
      add :sector_id, references(:sectors, on_delete: :delete_all), null: false
      add :name, :string
      add_lc_common()
    end

    create unique_index(:sectors_lc, [:sector_id, :locale_code, :version])

    create table(:activities) do
      add :key, :string, null: false
      add :sector_id, references(:sectors, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:activities, [:key])

    create table(:activities_lc) do
      add :activity_id, references(:activities, on_delete: :delete_all), null: false
      add :name, :string
      add_lc_common()
    end

    create unique_index(:activities_lc, [:activity_id, :locale_code, :version])

    # --- Partners ---
    create table(:partners) do
      add :slug, :string, null: false
      add :country_code, :string
      add :default_locale_code, :string, default: "en"
      add :status, :string, null: false, default: "active"
      add :trust_model, :string, null: false, default: "partner_facilitated"
      add :image_url, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:partners, [:slug])

    create table(:partners_lc) do
      add :partner_id, references(:partners, on_delete: :delete_all), null: false
      add :name, :string
      add :summary, :string
      add :profile, :text
      add_lc_common()
    end

    create unique_index(:partners_lc, [:partner_id, :locale_code, :version])

    # --- Borrowers ---
    create table(:borrowers) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :public_id, :string, null: false
      add :country_code, :string
      add :preferred_locale_code, :string, default: "en"
      add :partner_id, references(:partners, on_delete: :nilify_all)
      add :sector_id, references(:sectors, on_delete: :nilify_all)
      add :activity_id, references(:activities, on_delete: :nilify_all)
      add :image_url, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:borrowers, [:public_id])

    create table(:borrowers_lc) do
      add :borrower_id, references(:borrowers, on_delete: :delete_all), null: false
      add :display_name, :string
      add :public_bio, :text
      add :business_summary, :text
      add_lc_common()
    end

    create unique_index(:borrowers_lc, [:borrower_id, :locale_code, :version])

    # --- Loans ---
    create table(:loans) do
      add :slug, :string, null: false
      add :status, :string, null: false, default: "fundraising"
      add :partner_id, references(:partners, on_delete: :nilify_all)
      add :borrower_id, references(:borrowers, on_delete: :nilify_all)
      add :country_code, :string
      add :sector_id, references(:sectors, on_delete: :nilify_all)
      add :activity_id, references(:activities, on_delete: :nilify_all)
      add :trust_model, :string, null: false, default: "partner_facilitated"
      add :loan_amount_cents, :integer, null: false, default: 0
      add :funded_amount_cents, :integer, null: false, default: 0
      add :currency_code, :string, null: false, default: "USD"
      add :disbursal_status, :string, null: false, default: "pre_disbursed"
      add :disbursed_at, :utc_datetime
      add :fundraising_started_at, :utc_datetime
      add :fundraising_ends_at, :utc_datetime
      add :repayment_term_months, :integer
      add :repayment_frequency, :string, default: "monthly"
      add :source_locale_code, :string, null: false, default: "en"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:loans, [:slug])
    create index(:loans, [:status])
    create index(:loans, [:sector_id])
    create index(:loans, [:country_code])
    create index(:loans, [:trust_model])

    create table(:loans_lc) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :title, :string
      add :short_description, :text
      add :borrower_story, :text
      add :loan_use, :text
      add :repayment_summary, :text
      add :risk_summary_public, :text
      add_lc_common()
    end

    create unique_index(:loans_lc, [:loan_id, :locale_code, :version])
    create index(:loans_lc, [:translation_status])

    # --- Repayment schedule ---
    create table(:repayment_schedules) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :schedule_type, :string, default: "standard"
      add :starts_on, :date
      add :term_months, :integer
      add :frequency, :string, default: "monthly"
      timestamps(type: :utc_datetime)
    end

    create table(:repayment_schedule_items) do
      add :repayment_schedule_id, references(:repayment_schedules, on_delete: :delete_all),
        null: false

      add :due_on, :date
      add :amount_cents, :integer, null: false, default: 0
      add :status, :string, null: false, default: "scheduled"
      add :paid_on, :date
      timestamps(type: :utc_datetime)
    end

    create index(:repayment_schedule_items, [:repayment_schedule_id])
  end
end
