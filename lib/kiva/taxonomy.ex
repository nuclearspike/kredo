defmodule Kiva.Taxonomy do
  @moduledoc "Sectors and activities, with localized names."
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.Taxonomy.{Sector, SectorLc, Activity, ActivityLc}

  def list_sectors(locale) do
    Sector
    |> order_by(:key)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&%{id: &1.id, key: &1.key, name: name(&1, locale)})
  end

  def list_activities(locale) do
    Activity
    |> order_by(:key)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&%{id: &1.id, key: &1.key, sector_id: &1.sector_id, name: name(&1, locale)})
  end

  @doc "Resolved localized name for a sector/activity (with fallback), or its key."
  def name(%{translations: trs, key: key}, locale) when is_list(trs) do
    case Resolver.resolve_public(trs, locale).row do
      nil -> key
      row -> row.name
    end
  end

  def name(%{key: key}, _locale), do: key
  def name(nil, _locale), do: nil
  def name(_unloaded, _locale), do: nil

  # --- Authoring helpers (seeds) ---
  def upsert_sector(key) do
    Repo.insert!(%Sector{key: key}, on_conflict: :nothing, conflict_target: :key)
    Repo.get_by!(Sector, key: key)
  end

  def upsert_activity(key, sector_id) do
    Repo.insert!(%Activity{key: key, sector_id: sector_id},
      on_conflict: {:replace, [:sector_id]},
      conflict_target: :key
    )

    Repo.get_by!(Activity, key: key)
  end

  def upsert_sector_lc(attrs),
    do:
      %SectorLc{}
      |> SectorLc.changeset(attrs)
      |> Repo.insert!(
        on_conflict: {:replace, [:name]},
        conflict_target: [:sector_id, :locale_code, :version]
      )

  def upsert_activity_lc(attrs),
    do:
      %ActivityLc{}
      |> ActivityLc.changeset(attrs)
      |> Repo.insert!(
        on_conflict: {:replace, [:name]},
        conflict_target: [:activity_id, :locale_code, :version]
      )
end
