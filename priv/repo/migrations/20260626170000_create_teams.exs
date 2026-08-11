defmodule Kiva.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  defp add_lc_common do
    add :locale_code, :string, null: false
    add :is_source, :boolean, null: false, default: false
    add :source_locale_code, :string
    add :translation_status, :string, null: false, default: "draft"
    add :translated_from_lc_id, :integer
    add :version, :integer, null: false, default: 1
    add :source_hash, :string
    timestamps(type: :utc_datetime)
  end

  def change do
    create table(:lending_teams) do
      add :slug, :string, null: false
      add :owner_user_id, references(:users, on_delete: :nilify_all)
      add :visibility, :string, null: false, default: "public"
      add :image_url, :string
      add :image_source, :string, default: "placeholder"
      add :default_locale_code, :string, default: "en"
      add :member_count, :integer, null: false, default: 0
      add :total_lent_cents, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:lending_teams, [:slug])

    create table(:lending_teams_lc) do
      add :lending_team_id, references(:lending_teams, on_delete: :delete_all), null: false
      add :name, :string
      add :tagline, :string
      add :description, :text
      add :welcome_post_template, :text
      add_lc_common()
    end

    create unique_index(:lending_teams_lc, [:lending_team_id, :locale_code, :version])

    create table(:lending_team_memberships) do
      add :lending_team_id, references(:lending_teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:lending_team_memberships, [:lending_team_id, :user_id])

    create table(:team_posts) do
      add :lending_team_id, references(:lending_teams, on_delete: :delete_all), null: false
      add :author_user_id, references(:users, on_delete: :nilify_all)
      add :moderation_status, :string, null: false, default: "approved"
      add :source_locale_code, :string, null: false, default: "en"
      timestamps(type: :utc_datetime)
    end

    create index(:team_posts, [:lending_team_id])

    create table(:team_posts_lc) do
      add :team_post_id, references(:team_posts, on_delete: :delete_all), null: false
      add :body, :text
      add_lc_common()
    end

    create unique_index(:team_posts_lc, [:team_post_id, :locale_code, :version])

    create table(:lendings) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :loan_id, references(:loans, on_delete: :delete_all), null: false
      add :lending_team_id, references(:lending_teams, on_delete: :nilify_all)
      add :amount_cents, :integer, null: false, default: 2500
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:lendings, [:user_id])
    create index(:lendings, [:loan_id])
  end
end
