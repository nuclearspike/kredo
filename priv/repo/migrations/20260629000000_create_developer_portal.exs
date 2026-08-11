defmodule Kiva.Repo.Migrations.CreateDeveloperPortal do
  use Ecto.Migration

  def change do
    # Additive developer capability — any user can gain API access without losing
    # their existing role.
    alter table(:users) do
      add :developer_enabled, :boolean, null: false, default: false
    end

    # A developer application doubles as an OAuth2 client (app_id == client_id).
    create table(:developer_apps) do
      add :owner_user_id, references(:users, on_delete: :delete_all), null: false
      add :app_id, :string, null: false
      add :client_secret_hash, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :website, :string
      add :redirect_uris, {:array, :string}, null: false, default: []
      add :status, :string, null: false, default: "active"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:developer_apps, [:app_id])
    create index(:developer_apps, [:owner_user_id])

    # API keys for the bespoke Platform API (/api/v2). Only the SHA-256 hash is
    # stored; `key_id` is the indexed public lookup handle embedded in the raw key.
    create table(:developer_api_keys) do
      add :developer_app_id, references(:developer_apps, on_delete: :delete_all), null: false
      add :key_id, :string, null: false
      add :prefix, :string, null: false
      add :last4, :string, null: false
      add :token_hash, :string, null: false
      add :name, :string
      add :scopes, {:array, :string}, null: false, default: []
      add :last_used_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:developer_api_keys, [:key_id])
    create unique_index(:developer_api_keys, [:token_hash])
    create index(:developer_api_keys, [:developer_app_id])
  end
end
