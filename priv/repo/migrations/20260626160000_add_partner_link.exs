defmodule Kiva.Repo.Migrations.AddPartnerLink do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :managed_partner_id, references(:partners, on_delete: :nilify_all)
    end
  end
end
