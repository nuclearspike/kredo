defmodule Kiva.Repo.Migrations.CreateBasket do
  use Ecto.Migration

  def change do
    create table(:basket_items) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :amount_cents, :integer, null: false, default: 2500
      timestamps(type: :utc_datetime)
    end

    create unique_index(:basket_items, [:user_id, :loan_id])
  end
end
