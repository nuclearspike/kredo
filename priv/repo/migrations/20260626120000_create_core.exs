defmodule Kiva.Repo.Migrations.CreateCore do
  use Ecto.Migration

  def change do
    # --- Localization ---------------------------------------------------
    create table(:locales, primary_key: false) do
      add :code, :string, primary_key: true
      add :english_name, :string, null: false
      add :native_name, :string, null: false
      add :enabled, :boolean, default: true, null: false
      add :fallback_code, :string
      add :text_direction, :string, default: "ltr", null: false
      add :number_format, :string
      add :currency_format, :string
      add :date_format, :string
      timestamps(type: :utc_datetime)
    end

    # --- Identity & access ----------------------------------------------
    create table(:roles) do
      add :key, :string, null: false
      add :label, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:key])

    create table(:permissions) do
      add :key, :string, null: false
      add :label, :string, null: false
      add :risk_level, :string, null: false, default: "low"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:permissions, [:key])

    create table(:permission_groups) do
      add :key, :string, null: false
      add :label, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:permission_groups, [:key])

    create table(:permission_group_permissions, primary_key: false) do
      add :permission_group_id, references(:permission_groups, on_delete: :delete_all),
        null: false

      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
    end

    create unique_index(:permission_group_permissions, [:permission_group_id, :permission_id])

    create table(:users) do
      add :email, :string, null: false
      add :encrypted_password, :string, null: false
      add :display_name, :string
      add :role, :string, null: false, default: "lender"

      add :default_locale_code,
          references(:locales, column: :code, type: :string, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:role])

    create table(:user_permission_groups, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :permission_group_id, references(:permission_groups, on_delete: :delete_all),
        null: false
    end

    create unique_index(:user_permission_groups, [:user_id, :permission_group_id])

    # Direct grants — powers the Phase 7 permission-outlier dashboard.
    create table(:user_permissions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
      add :granted_by_user_id, references(:users, on_delete: :nilify_all)
      add :reason, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_permissions, [:user_id, :permission_id])
  end
end
