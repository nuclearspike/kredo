defmodule Kiva.Partners do
  @moduledoc "Lending partners, with localized name/summary/profile."
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.Partners.{Partner, PartnerLc}

  def list_localized_partners(locale) do
    Partner
    |> order_by(:slug)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&localize(&1, locale))
  end

  def get_localized_partner(slug, locale) do
    case Repo.get_by(Partner, slug: slug) |> Repo.preload(:translations) do
      nil -> nil
      partner -> localize(partner, locale)
    end
  end

  def get_partner_by_slug(slug),
    do: Repo.get_by(Partner, slug: slug) |> Repo.preload(:translations)

  @doc "Kiva-compat: a page of partners (raw, with translations): `{partners, total}`."
  def kiva_list(limit, offset) do
    total = Repo.aggregate(Partner, :count)

    rows =
      Partner
      |> order_by(:id)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(:translations)
      |> Repo.all()

    {rows, total}
  end

  @doc "Kiva-compat: partners by id (raw, with translations), order preserved."
  def kiva_by_ids([]), do: []

  def kiva_by_ids(ids) do
    by_id =
      Partner
      |> where([p], p.id in ^ids)
      |> preload(:translations)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.flat_map(ids, fn id -> if p = by_id[id], do: [p], else: [] end)
  end

  @doc "Admin: set a partner's status (active | suspended)."
  def set_status(id, status) do
    Repo.get!(Partner, id) |> Partner.changeset(%{status: status}) |> Repo.update!()
  end

  defp localize(%Partner{} = p, locale) do
    res = Resolver.resolve_public(p.translations, locale)

    %{
      partner: p,
      lc: res.row,
      resolved_locale: res.locale,
      fallback_used: res.fallback_used,
      name: (res.row && res.row.name) || p.slug,
      summary: res.row && res.row.summary,
      profile: res.row && res.row.profile
    }
  end

  # --- Authoring helpers (seeds) ---
  def upsert_partner(attrs) do
    Repo.insert!(struct(Partner, attrs),
      on_conflict: {:replace, [:country_code, :trust_model, :image_url, :status]},
      conflict_target: :slug
    )

    Repo.get_by!(Partner, slug: attrs.slug)
  end

  def upsert_partner_lc(attrs),
    do:
      %PartnerLc{}
      |> PartnerLc.changeset(attrs)
      |> Repo.insert!(
        on_conflict: {:replace, [:name, :summary, :profile, :translation_status]},
        conflict_target: [:partner_id, :locale_code, :version]
      )
end
