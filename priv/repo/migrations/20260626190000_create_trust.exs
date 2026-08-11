defmodule Kiva.Repo.Migrations.CreateTrust do
  use Ecto.Migration

  defp add_lc_common do
    add :locale_code, :string, null: false
    add :is_source, :boolean, null: false, default: false
    add :source_locale_code, :string
    add :translation_status, :string, null: false, default: "published"
    add :version, :integer, null: false, default: 1
    timestamps(type: :utc_datetime)
  end

  def change do
    create table(:trustees) do
      add :slug, :string, null: false
      add :country_code, :string
      add :status, :string, null: false, default: "active"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:trustees, [:slug])

    create table(:trustees_lc) do
      add :trustee_id, references(:trustees, on_delete: :delete_all), null: false
      add :name, :string
      add :bio, :text
      add_lc_common()
    end

    create unique_index(:trustees_lc, [:trustee_id, :locale_code, :version])

    create table(:trust_endorsements) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :trustee_id, references(:trustees, on_delete: :nilify_all)
      add :borrower_id, references(:borrowers, on_delete: :nilify_all)
      add :status, :string, null: false, default: "endorsed"
      add :source_locale_code, :string, null: false, default: "en"
      timestamps(type: :utc_datetime)
    end

    create index(:trust_endorsements, [:loan_id])

    create table(:trust_endorsements_lc) do
      add :trust_endorsement_id, references(:trust_endorsements, on_delete: :delete_all),
        null: false

      add :statement, :text
      add_lc_common()
    end

    create unique_index(:trust_endorsements_lc, [:trust_endorsement_id, :locale_code, :version])

    create table(:alternative_checks) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :borrower_id, references(:borrowers, on_delete: :nilify_all)
      add :check_type, :string, null: false
      add :status, :string, null: false, default: "passed"
      add :detail, :string
      timestamps(type: :utc_datetime)
    end

    create index(:alternative_checks, [:loan_id])

    create table(:blockchain_attestations) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :attestation_type, :string, null: false, default: "loan_integrity"
      add :proof_hash, :string, null: false
      add :chain, :string, null: false, default: "mock-attest-v0"
      add :verified, :boolean, null: false, default: true
      add :attested_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:blockchain_attestations, [:loan_id, :attestation_type])
  end
end
