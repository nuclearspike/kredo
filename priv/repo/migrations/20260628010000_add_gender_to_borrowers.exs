defmodule Kiva.Repo.Migrations.AddGenderToBorrowers do
  use Ecto.Migration

  # Kiva's public API exposes borrower gender (legacy `borrowers[].gender` = "M"/"F";
  # GraphQL `GenderEnum`) and a `gender` search filter. We don't model it yet, so the
  # Kiva-compatibility layer needs a real column to filter and serialize against.
  # Nullable: absent => "unspecified" / omitted, matching Kiva's anonymized loans.
  def change do
    alter table(:borrowers) do
      add :gender, :string
    end
  end
end
