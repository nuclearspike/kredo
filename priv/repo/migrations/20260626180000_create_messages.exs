defmodule Kiva.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:encouragement_messages) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :borrower_id, references(:borrowers, on_delete: :nilify_all)
      add :sender_user_id, references(:users, on_delete: :nilify_all)
      add :moderation_status, :string, null: false, default: "pending"
      add :source_locale_code, :string, null: false, default: "en"
      timestamps(type: :utc_datetime)
    end

    create index(:encouragement_messages, [:borrower_id])
    create index(:encouragement_messages, [:loan_id])

    create table(:encouragement_messages_lc) do
      add :encouragement_message_id, references(:encouragement_messages, on_delete: :delete_all),
        null: false

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

    create unique_index(:encouragement_messages_lc, [
             :encouragement_message_id,
             :locale_code,
             :version
           ])
  end
end
