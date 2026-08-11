defmodule Kiva.Repo.Migrations.CreateLocalizationContent do
  use Ecto.Migration

  def change do
    # Canonical FAQ entry — identity & ordering only, no actor-facing text.
    create table(:faq_entries) do
      add :slug, :string, null: false
      add :category, :string
      add :position, :integer, default: 0, null: false
      add :source_locale_code, :string, null: false, default: "en"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:faq_entries, [:slug])

    # Language-content sidecar — generic *_lc column set (see 03_data_model).
    create table(:faq_entries_lc) do
      add :faq_entry_id, references(:faq_entries, on_delete: :delete_all), null: false
      add :locale_code, :string, null: false
      add :is_source, :boolean, default: false, null: false
      add :source_locale_code, :string
      add :question, :string
      add :answer, :text
      add :translation_status, :string, null: false, default: "draft"
      add :translated_by_ai_model, :string
      add :translated_from_lc_id, :integer
      add :human_reviewer_user_id, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime
      add :published_at, :utc_datetime
      add :version, :integer, default: 1, null: false
      add :source_hash, :string
      add :field_completeness_score, :float
      timestamps(type: :utc_datetime)
    end

    create unique_index(:faq_entries_lc, [:faq_entry_id, :locale_code, :version])
    create index(:faq_entries_lc, [:translation_status])

    # On-demand / tracked translation work.
    create table(:translation_requests) do
      add :entity_type, :string, null: false
      add :entity_id, :integer, null: false
      add :source_locale_code, :string, null: false
      add :target_locale_code, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :requested_by_user_id, references(:users, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:translation_requests, [:entity_type, :entity_id, :target_locale_code],
             name: :translation_requests_entity_target_index
           )
  end
end
