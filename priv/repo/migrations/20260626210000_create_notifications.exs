defmodule Kiva.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :title, :string
      add :body, :text
      add :link, :string
      add :read_at, :utc_datetime
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read_at])
  end
end
