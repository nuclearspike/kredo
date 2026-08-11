defmodule Kiva.Repo.Migrations.CreateAiAndAudit do
  use Ecto.Migration

  def change do
    create table(:audit_events) do
      add :actor_user_id, references(:users, on_delete: :nilify_all)
      add :actor_role, :string
      add :event_type, :string, null: false
      add :target_type, :string
      add :target_id, :string
      add :summary, :string
      add :metadata, :map, default: %{}
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:audit_events, [:event_type])
    create index(:audit_events, [:actor_user_id])

    create table(:ai_conversations) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :actor_role, :string, null: false, default: "public"
      add :locale_code, :string, null: false, default: "en"
      add :page_context, :map, default: %{}
      timestamps(type: :utc_datetime)
    end

    create table(:ai_messages) do
      add :ai_conversation_id, references(:ai_conversations, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :mode, :string
      add :content, :text
      add :metadata, :map, default: %{}
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:ai_messages, [:ai_conversation_id])

    create table(:ai_tool_calls) do
      add :ai_conversation_id, references(:ai_conversations, on_delete: :delete_all), null: false
      add :tool_type, :string, null: false
      add :schema_surface, :string
      add :operation_name, :string
      add :allowed, :boolean, null: false, default: true
      add :denial_reason, :string
      add :request, :map, default: %{}
      add :response_summary, :text
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:ai_tool_calls, [:ai_conversation_id])

    create table(:ai_action_previews) do
      add :ai_conversation_id, references(:ai_conversations, on_delete: :delete_all), null: false
      add :command_key, :string, null: false
      add :target_type, :string
      add :target_id, :string
      add :preview, :map, default: %{}
      add :risk_level, :string
      add :confirmed_at, :utc_datetime
      add :executed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:ai_action_previews, [:ai_conversation_id])
  end
end
