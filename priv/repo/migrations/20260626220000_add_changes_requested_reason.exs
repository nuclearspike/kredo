defmodule Kiva.Repo.Migrations.AddChangesRequestedReason do
  use Ecto.Migration

  def change do
    alter table(:loans) do
      add :changes_requested_reason, :text
    end
  end
end
