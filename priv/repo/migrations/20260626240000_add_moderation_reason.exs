defmodule Kiva.Repo.Migrations.AddModerationReason do
  use Ecto.Migration

  def change do
    alter table(:encouragement_messages) do
      add :moderation_reason, :string
    end
  end
end
