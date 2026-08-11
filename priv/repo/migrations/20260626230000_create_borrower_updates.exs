defmodule Kiva.Repo.Migrations.CreateBorrowerUpdates do
  use Ecto.Migration

  def change do
    create table(:borrower_updates) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :borrower_id, references(:borrowers, on_delete: :nilify_all)
      add :author_user_id, references(:users, on_delete: :nilify_all)
      add :kind, :string, null: false, default: "update"
      add :source_locale_code, :string, null: false, default: "en"
      timestamps(type: :utc_datetime)
    end

    create index(:borrower_updates, [:loan_id])

    create table(:borrower_updates_lc) do
      add :borrower_update_id, references(:borrower_updates, on_delete: :delete_all), null: false
      add :body, :text
      add :locale_code, :string, null: false
      add :is_source, :boolean, null: false, default: false
      add :source_locale_code, :string
      add :translation_status, :string, null: false, default: "draft"
      add :translated_from_lc_id, :integer
      add :version, :integer, null: false, default: 1
      add :source_hash, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:borrower_updates_lc, [:borrower_update_id, :locale_code, :version])
  end
end
