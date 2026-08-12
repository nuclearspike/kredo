defmodule Kiva.Teams do
  @moduledoc """
  Lending teams: conversational creation (localized team page + translation
  requests), membership, and a message board with on-demand post translation.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.{Localization, Translation, Audit}
  alias Kiva.Teams.{Team, TeamLc, TeamMembership, TeamPost, TeamPostLc}
  alias Kiva.Accounts.User

  # --- creation ---
  def create_team(owner, attrs) do
    name = attrs["name"] || attrs[:name]
    src = attrs["source_locale_code"] || attrs[:source_locale_code] || "en"
    oid = owner_id(owner)

    {:ok, team} =
      %Team{}
      |> Team.changeset(%{
        slug: unique_slug(name),
        owner_user_id: oid,
        visibility: attrs["visibility"] || attrs[:visibility] || "public",
        image_url: attrs["image_url"],
        image_source: if(attrs["image_url"], do: "external_url", else: "placeholder"),
        default_locale_code: src,
        member_count: 1
      })
      |> Repo.insert()

    %TeamLc{}
    |> TeamLc.changeset(%{
      lending_team_id: team.id,
      locale_code: src,
      is_source: true,
      source_locale_code: src,
      name: name,
      tagline: attrs["tagline"],
      description: attrs["description"],
      welcome_post_template: attrs["welcome_post"],
      translation_status: "published"
    })
    |> Repo.insert!()

    if oid do
      %TeamMembership{}
      |> TeamMembership.changeset(%{lending_team_id: team.id, user_id: oid, role: "owner"})
      |> Repo.insert!()
    end

    for t <- Localization.supported_locales(), t != src do
      Translation.upsert_request(%{
        entity_type: "lending_team",
        entity_id: team.id,
        source_locale_code: src,
        target_locale_code: t,
        status: "pending"
      })
    end

    Audit.record(%{
      event_type: "team.created",
      actor_user_id: oid,
      target_type: "lending_team",
      target_id: to_string(team.id),
      summary: "Created team #{name}"
    })

    team
  end

  # --- reads ---
  def list_localized_teams(locale) do
    Team
    |> order_by(:slug)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&localize_team(&1, locale))
  end

  def get_localized_team(slug, locale) do
    team =
      Team
      |> where(slug: ^slug)
      |> preload([:translations, posts: :translations])
      |> Repo.one()

    if team do
      base = localize_team(team, locale)

      author_ids =
        team.posts |> Enum.map(& &1.author_user_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

      authors = Map.new(Repo.all(from u in User, where: u.id in ^author_ids), &{&1.id, &1})

      members =
        Map.new(
          Repo.all(
            from m in TeamMembership,
              where: m.lending_team_id == ^team.id and m.user_id in ^author_ids
          ),
          &{&1.user_id, &1}
        )

      posts =
        team.posts
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
        |> Enum.map(&localize_post(&1, locale, authors, members, team.owner_user_id))

      Map.merge(base, %{posts: posts, member_count: team.member_count})
    end
  end

  @doc "Kiva-compat: team search by name/description (`q` optional): `{teams, total}`."
  def kiva_search(q, limit, offset) do
    base =
      case q do
        term when is_binary(term) and term != "" ->
          like = "%#{term}%"

          from t in Team,
            where:
              fragment(
                "EXISTS (SELECT 1 FROM lending_teams_lc lc WHERE lc.lending_team_id = ? AND (lc.name ILIKE ? OR lc.description ILIKE ?))",
                t.id,
                ^like,
                ^like
              )

        _ ->
          Team
      end

    total = Repo.aggregate(base, :count)

    rows =
      base
      |> order_by(:id)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(:translations)
      |> Repo.all()

    {rows, total}
  end

  @doc "Kiva-compat: raw teams (with translations) a user belongs to."
  def kiva_user_teams(user_id) do
    from(t in Team,
      join: m in TeamMembership,
      on: m.lending_team_id == t.id,
      where: m.user_id == ^user_id,
      order_by: t.id,
      preload: :translations
    )
    |> Repo.all()
  end

  @doc "Kiva-compat: teams by id (raw, with translations), order preserved."
  def kiva_by_ids([]), do: []

  def kiva_by_ids(ids) do
    by_id =
      Team
      |> where([t], t.id in ^ids)
      |> preload(:translations)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.flat_map(ids, fn id -> if t = by_id[id], do: [t], else: [] end)
  end

  def get_team_by_slug(slug), do: Repo.get_by(Team, slug: slug)

  @doc "Teams the user belongs to (for the lend-on-behalf-of-a-team selector)."
  def list_user_teams(user_id, locale) do
    Repo.all(
      from t in Team,
        join: m in TeamMembership,
        on: m.lending_team_id == t.id,
        where: m.user_id == ^user_id,
        order_by: t.slug,
        preload: :translations
    )
    |> Enum.map(fn t -> %{id: t.id, name: team_name(t, locale)} end)
  end

  @doc "Recent lendings attributed to a team (the team's lending feed)."
  def team_lending_summary(team_id, locale) do
    lendings =
      Repo.all(
        from l in Kiva.Portfolio.Lend,
          where: l.lending_team_id == ^team_id,
          order_by: [desc: l.inserted_at],
          limit: 8,
          preload: [loan: :translations]
      )

    recent =
      Enum.map(lendings, fn l ->
        title =
          case Resolver.resolve_public(l.loan.translations, locale).row do
            nil -> l.loan.slug
            row -> row.title
          end

        %{title: title, amount_cents: l.amount_cents, slug: l.loan.slug}
      end)

    %{count: length(lendings), recent: recent}
  end

  defp team_name(%Team{} = t, locale) do
    case Resolver.resolve_public(t.translations, locale).row do
      nil -> t.slug
      row -> row.name
    end
  end

  # --- message board ---
  def add_post(team_id, author, body, source_locale) do
    src = source_locale || "en"

    {:ok, post} =
      %TeamPost{}
      |> TeamPost.changeset(%{
        lending_team_id: team_id,
        author_user_id: owner_id(author),
        moderation_status: "approved",
        source_locale_code: src
      })
      |> Repo.insert()

    %TeamPostLc{}
    |> TeamPostLc.changeset(%{
      team_post_id: post.id,
      locale_code: src,
      is_source: true,
      source_locale_code: src,
      body: body,
      translation_status: "published"
    })
    |> Repo.insert!()

    Audit.record(%{
      event_type: "team.post_created",
      actor_user_id: owner_id(author),
      target_type: "lending_team",
      target_id: to_string(team_id),
      summary: "Posted to team board"
    })

    post
  end

  @doc "On-demand machine translation of a board post (long-tail content)."
  def ensure_post_translation(post_id, target_locale) do
    post = Repo.get!(TeamPost, post_id) |> Repo.preload(:translations)
    target = Localization.normalize(target_locale)
    source = Enum.find(post.translations, & &1.is_source) || List.first(post.translations)

    cond do
      is_nil(source) ->
        {:error, :no_source}

      existing = Enum.find(post.translations, &(&1.locale_code == target)) ->
        {:ok, existing}

      true ->
        {:ok, row} =
          %TeamPostLc{}
          |> TeamPostLc.changeset(%{
            team_post_id: post.id,
            locale_code: target,
            is_source: false,
            source_locale_code: source.locale_code,
            body: Translation.machine_translate(source.body, source.locale_code, target),
            translated_from_lc_id: source.id,
            translation_status: "machine",
            source_hash: Translation.source_hash(source.body)
          })
          |> Repo.insert()

        Translation.upsert_request(%{
          entity_type: "team_post",
          entity_id: post.id,
          source_locale_code: source.locale_code,
          target_locale_code: target,
          status: "machine_translated"
        })

        {:ok, row}
    end
  end

  # --- helpers ---
  defp localize_team(%Team{} = team, locale) do
    res = Resolver.resolve_public(team.translations, locale)

    %{
      team: team,
      lc: res.row,
      resolved_locale: res.locale,
      fallback_used: res.fallback_used,
      name: (res.row && res.row.name) || team.slug,
      tagline: res.row && res.row.tagline,
      description: res.row && res.row.description
    }
  end

  defp localize_post(%TeamPost{} = post, locale, authors, members, owner_id) do
    res = Resolver.resolve_public(post.translations, locale)
    author = post.author_user_id && Map.get(authors, post.author_user_id)
    membership = post.author_user_id && Map.get(members, post.author_user_id)

    %{
      post: post,
      body: res.row && res.row.body,
      resolved_locale: res.locale,
      fallback_used: res.fallback_used,
      status: res.row && res.row.translation_status,
      author_name: author && (author.display_name || author.email),
      author_role: author && author.role,
      author_avatar: author && author.avatar_url,
      captain?: not is_nil(post.author_user_id) and post.author_user_id == owner_id,
      posted_at: post.inserted_at,
      joined_at: membership && membership.inserted_at
    }
  end

  defp unique_slug(name) do
    base =
      (name || "team")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    base = if base == "", do: "team", else: base

    if Repo.exists?(from t in Team, where: t.slug == ^base),
      do: "#{base}-#{System.unique_integer([:positive])}",
      else: base
  end

  defp owner_id(%{id: id}), do: id
  defp owner_id(_), do: nil

  # --- seeds ---
  def upsert_team(attrs) do
    Repo.insert!(struct(Team, attrs),
      on_conflict: {:replace, [:image_url, :visibility]},
      conflict_target: :slug
    )

    Repo.get_by!(Team, slug: attrs.slug)
  end

  def upsert_team_lc(attrs),
    do:
      %TeamLc{}
      |> TeamLc.changeset(attrs)
      |> Repo.insert!(
        on_conflict: {:replace, [:name, :tagline, :description]},
        conflict_target: [:lending_team_id, :locale_code, :version]
      )
end
