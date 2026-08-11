defmodule Kiva.Repo.Migrations.CreateProvenanceEvents do
  use Ecto.Migration

  def change do
    create table(:provenance_events) do
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :subject_type, :string, null: false
      add :subject_ref, :string
      add :event_type, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :actor_kind, :string, null: false
      add :actor_name, :string, null: false
      add :actor_role, :string
      add :actor_user_id, :integer
      add :tool, :map, default: %{}
      add :location, :map
      add :source_locale, :string
      add :target_locale, :string
      add :source_hash, :string
      add :content_hash, :string
      add :visibility, :string, null: false, default: "admin"
      add :details, :map, default: %{}
      # Append-only by construction: no updated_at, no update/delete API.
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:provenance_events, [:loan_id, :occurred_at])
    create index(:provenance_events, [:event_type])

    # Append-only enforced at the database: updates always raise; deletes raise
    # unless the row is a re-derivable fabricated demo fixture
    # (details.fabricated = true). Cascading a loan delete over live provenance
    # is intentionally blocked — audit rows outlive convenience.
    execute(
      """
      CREATE OR REPLACE FUNCTION provenance_events_append_only() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'UPDATE' THEN
          RAISE EXCEPTION 'provenance_events is append-only';
        END IF;
        IF COALESCE(OLD.details->>'fabricated', 'false') <> 'true' THEN
          RAISE EXCEPTION 'live provenance events cannot be deleted';
        END IF;
        RETURN OLD;
      END $$ LANGUAGE plpgsql;
      """,
      "DROP FUNCTION IF EXISTS provenance_events_append_only()"
    )

    execute(
      """
      CREATE TRIGGER provenance_events_guard
      BEFORE UPDATE OR DELETE ON provenance_events
      FOR EACH ROW EXECUTE FUNCTION provenance_events_append_only();
      """,
      "DROP TRIGGER IF EXISTS provenance_events_guard ON provenance_events"
    )
  end
end
